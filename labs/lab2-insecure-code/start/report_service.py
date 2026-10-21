"""Small internal service that builds, archives and fetches customer reports.

LAB FILE: every function below contains a deliberate security bug.
Each "RISK" comment explains what an attacker could do and how the
fixed version (solution/report_service.py) avoids it.
"""
import hashlib
import os
import pickle
import random
import socket
import sqlite3
import ssl
import subprocess
import tempfile

import jwt
import requests
import yaml
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from flask import Flask

app = Flask(__name__)

# RISK: the password is written in the code, so anyone who can
# read the repo or its Git history has it.
# FIX: read it from the environment or a secrets manager.
ADMIN_PASSWORD = "admin123"


def is_admin(password):
    # RISK: "==" stops at the first wrong character, so
    # a wrong guess fails slightly faster the earlier it goes wrong. By timing
    # many attempts, an attacker can work out the password character by character.
    # FIX: secrets.compare_digest(), which always takes the same time.
    return password == ADMIN_PASSWORD


def load_settings(path):
    # RISK: the full YAML loader can create any Python object,
    # so a crafted settings file can make this program run code.
    # FIX: yaml.safe_load(), which only reads plain data.
    with open(path) as f:
        return yaml.load(f, Loader=yaml.Loader)


def archive_report(filename):
    # RISK: with shell=True the text goes to a shell, so a
    # filename like "x; rm -rf /" runs a second command (command injection).
    # RISK: "../../" in the filename can reach files outside reports/.
    # RISK: /tmp is shared by every user and process on the
    # machine, so others can pre-create or swap files there.
    # FIX: pass a list of arguments (no shell), keep only the file's name,
    # and write to a dedicated folder.
    subprocess.run(f"tar -czf /tmp/{filename}.tar.gz reports/{filename}", shell=True)


def calculate(expression):
    # Used by the report builder for totals, e.g. "120 * 3"
    # RISK: eval() runs any Python text it is given, so an
    # attacker can send code instead of a sum and the server runs it.
    # FIX: allow only a fixed set of operations on numbers.
    return eval(expression)


def fetch_report(url):
    # RISK: verify=False turns off the TLS certificate check, so
    # anyone between us and the server can read or change the traffic
    # (man-in-the-middle).
    # RISK: no timeout, so a slow or malicious server can make
    # this call hang forever.
    # FIX: keep certificate checking on (the default) and set timeout=10.
    return requests.get(url, verify=False)


def load_cached_report(blob):
    # RISK: loading pickle data can run code, so anyone who can
    # change the cached data can take over the service.
    # FIX: store and load plain data with JSON.
    return pickle.loads(blob)


def hash_password(password):
    # RISK: MD5 is extremely fast and unsalted, so stolen hashes
    # can be cracked with billions of guesses per second or looked up in
    # precomputed tables.
    # FIX: a slow, salted hash such as PBKDF2, bcrypt or argon2.
    return hashlib.md5(password.encode()).hexdigest()


def new_session_token():
    # RISK: the random module is predictable by design, and a
    # 6-digit number has only 900,000 values, so an attacker can guess a valid
    # token and take over someone's session.
    # FIX: secrets.token_urlsafe(), which is cryptographically secure.
    return str(random.randint(100000, 999999))


def find_customer(db_path, customer_id):
    # RISK: the customer ID is pasted into the SQL text, so an ID like
    # "x' OR '1'='1" returns every customer (SQL injection).
    # FIX: a parameterised query; the database treats the ID as data, never as SQL.
    conn = sqlite3.connect(db_path)
    return conn.execute(f"SELECT name, email FROM customers WHERE id = '{customer_id}'").fetchall()


def write_temp_report(data):
    # RISK: mktemp() only picks a name; another process can create that file
    # first and receive our data (a race condition).
    # RISK: mode 777 lets every user on the machine read and change the report.
    # FIX: mkstemp(), which creates the file safely, readable only by its owner.
    path = tempfile.mktemp(suffix=".csv")
    with open(path, "w") as f:
        f.write(data)
    os.chmod(path, 0o777)
    return path


def open_partner_connection(host):
    # RISK: an "unverified" TLS context accepts any certificate, so an
    # attacker can pretend to be the partner and read everything we send.
    # FIX: ssl.create_default_context(), which verifies the certificate,
    # and require TLS 1.2 or newer.
    context = ssl._create_unverified_context()
    return context.wrap_socket(socket.create_connection((host, 443)), server_hostname=host)


def read_user_from_token(token):
    # RISK: the token's signature is not checked, so anyone can write their own
    # token saying "I am the admin" and it is accepted.
    # FIX: decode with the signing key and an explicit list of allowed algorithms.
    return jwt.decode(token, options={"verify_signature": False})


def encrypt_report(key, data):
    # RISK: ECB mode encrypts identical blocks to identical output, so patterns
    # in the data stay visible even when encrypted.
    # FIX: an authenticated mode such as AES-GCM with a fresh random nonce.
    encryptor = Cipher(algorithms.AES(key), modes.ECB()).encryptor()
    return encryptor.update(data) + encryptor.finalize()


def new_signing_key():
    # RISK: 1024-bit RSA keys are too short by today's standards and can be
    # broken by a well-funded attacker.
    # FIX: at least 2048 bits (3072 recommended).
    return rsa.generate_private_key(public_exponent=65537, key_size=1024)


@app.route("/health")
def health():
    return "ok"


if __name__ == "__main__":
    # RISK: debug mode shows an interactive console on errors, which lets
    # anyone who can reach the page run code on the server.
    # RISK: 0.0.0.0 listens on every network interface, not just this machine.
    # FIX: debug off, and listen only where needed (here: localhost).
    app.run(host="0.0.0.0", debug=True)
