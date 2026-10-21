"""Small internal service that builds, archives and fetches customer reports."""
import hashlib
import json
import operator
import os
import secrets
import socket
import sqlite3
import ssl
import subprocess  # nosec B404 - only called below with a fixed argument list and no shell
import tempfile
from pathlib import Path

import jwt
import requests
import yaml
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from flask import Flask

app = Flask(__name__)

# From the environment (or a secrets manager), never from the code.
ADMIN_PASSWORD = os.environ["ADMIN_PASSWORD"]
ARCHIVE_DIR = Path(os.environ.get("ARCHIVE_DIR", "archives"))

OPERATIONS = {
    "+": operator.add,
    "-": operator.sub,
    "*": operator.mul,
    "/": operator.truediv,
}


def is_admin(password):
    # Constant-time comparison, so response timing doesn't leak the password.
    return secrets.compare_digest(password, ADMIN_PASSWORD)


def load_settings(path):
    with open(path) as f:
        return yaml.safe_load(f)


def archive_report(filename):
    name = Path(filename).name  # drops any "../" or "; rm -rf" tricks
    ARCHIVE_DIR.mkdir(exist_ok=True)
    subprocess.run(  # nosec B603 B607 - fixed argument list, no shell
        ["tar", "-czf", str(ARCHIVE_DIR / f"{name}.tar.gz"), "-C", "reports", name],
        check=True,
    )


def calculate(left, op, right):
    # Only the operations we support, instead of running whatever text we receive.
    return OPERATIONS[op](float(left), float(right))


def fetch_report(url):
    return requests.get(url, timeout=10)


def load_cached_report(blob):
    return json.loads(blob)


def hash_password(password):
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 600_000)
    return f"{salt.hex()}:{digest.hex()}"


def new_session_token():
    return secrets.token_urlsafe(32)


def find_customer(db_path, customer_id):
    # Parameterised query: the "?" is filled in by the database as data.
    with sqlite3.connect(db_path) as conn:
        return conn.execute(
            "SELECT name, email FROM customers WHERE id = ?", (customer_id,)
        ).fetchall()


def write_temp_report(data):
    # mkstemp() creates the file atomically, readable and writable by its owner only.
    fd, path = tempfile.mkstemp(suffix=".csv")
    with os.fdopen(fd, "w") as f:
        f.write(data)
    return path


def open_partner_connection(host):
    context = ssl.create_default_context()  # verifies the certificate and hostname
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    sock = socket.create_connection((host, 443), timeout=10)
    return context.wrap_socket(sock, server_hostname=host)


def read_user_from_token(token, signing_key):
    return jwt.decode(token, signing_key, algorithms=["HS256"])


def encrypt_report(key, data):
    nonce = secrets.token_bytes(12)
    encryptor = Cipher(algorithms.AES(key), modes.GCM(nonce)).encryptor()
    ciphertext = encryptor.update(data) + encryptor.finalize()
    return nonce + encryptor.tag + ciphertext


def new_signing_key():
    return rsa.generate_private_key(public_exponent=65537, key_size=3072)


@app.route("/health")
def health():
    return "ok"


if __name__ == "__main__":
    app.run(host="127.0.0.1", debug=False)
