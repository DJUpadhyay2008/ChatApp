import time

import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from fastapi.testclient import TestClient

from app.core.config import settings
from app.core.security import jwks_manager
from app.main import app

TEST_KID = "test-key-id-123"

# Fixed deterministic RSA private key for consistent test execution
FIXED_PEM = (
    b"-----BEGIN PRIVATE KEY-----\n"
    b"MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDLA+RFtezXodqF\n"
    b"zIqibvLtfkUZeCr2Jhkei5SoWaWXoLP69zOP0sl6c9gNz0UD6ZNa31xR7NUl4qqz\n"
    b"QziVa19R3H8J+vb/tg0K0tWF+Py2FONjxSsX6/UuCZvDxJz3ogW5giQMYChlcYPe\n"
    b"IzRAJZ0hKVtVflZPh0r5mdlrmwwSqKCfA4f0TnRZaTnggN/bG7DrBxIAdA9+458n\n"
    b"c77RHphYpkQ2ByKwRcH+oKOR8urtXYe0IGwzHZTXfPwWSUL8UVJVD6No8IWOJzxP\n"
    b"haeizUn2AgYoxZbeKNBUL50FWe8u8Q6p8Av67MamVBLKknnZjlOKQ9pvPYfOWI2e\n"
    b"iaKhvmw/AgMBAAECggEADJDemcQDd2tgw8Rf1mMIrVOSAlwSSK8eAeqA1pTJ76M2\n"
    b"ULPpYJ8a8nXmKyCntHDKOqc1pyqCHPi1OShRgcomGcKMqHj8veIuV3uqVMMPHVQY\n"
    b"qQ3Et5PW1rUoi4sJbjh8ozlfctam2XSXxXGnY8sQOUO+kAGkZQLKTL3Nm9/6dNMX\n"
    b"842lzGTvrnq4EsTx1Kj7sM1S4L0njjdSZVSV5NLAfFxLNNBrJgLlj5qMrii7jFCU\n"
    b"4lxl1F7hZUeVkYEBE1hvz9+soiJJ2kP2byAX/1e/1DA3TtEguKUpvfSeC+vfkkMp\n"
    b"a7vWfKZ/cf5BbOJYajR3pXlWXEbTpom2bsrkC1gdOQKBgQDtN+Sq6vpKnZa32+Qj\n"
    b"/dlLaGooe27tjU3uIztPa9Cdu+o1cgD0VRXsuvIOvRRiUbhilgFEzONJhj0bc7TI\n"
    b"w0Zat8k3LHVMY7mqvVmRiuRdWcul1vmcydpWu9haP1eq4xhCYSA8N5eox4eVmxD0\n"
    b"5ARSJNCPHLdQctbJnp83prx2aQKBgQDbFr7aYhuU1ZOuEYxh5XmoUv8hHUR5nBSQ\n"
    b"cV4xBMVUUGMaFj8rpZ7eOcxp76H/2UMwGijcUJF2QK9OJ4uS+IuKgvWsxuInfe6t\n"
    b"HMHFql6MP1BQagDDyeioCRfePTHJuxe0qCcLlzh1l4FEygqy1f4CKESCeNnW97WU\n"
    b"YkgU0ouIZwKBgQDCjdLXczywMatJQ+lKs4mh1RMr/IAwCHJf2zlrm+tPUq12A/hQ\n"
    b"a/A9Zd3cxKqRMKDfClQkDz5iMNyxRSaCedWb1ZwLykSx0CCYrg9l1NoSzfC+JSA3\n"
    b"vT17YTjCW60VFIfy+SGtAZM689p5kuJHVzNMA7GhjlWyf101owjGZdOv8QKBgCGF\n"
    b"/XYVBPtlIs/Dx6NDJbZn3LoIbG3fQBZKAoulmzwngMKBHPFkykZeubSMAlHPwMQf\n"
    b"fJkZiuh5RVnEG0tF1LRBDa5+UCSS1G6Qs+W3B/iVx4hGcA+FWaA8o/ZRjsi7ZAk0\n"
    b"oaTYYr87i4AnGjP7In7aAoGkVFDcXmByGW12OfuJAoGBAMy+QncY5QlYx5s6XUnx\n"
    b"m+7xwQZcWDcl8n4NI+rKyfRDwHPH4zLXpz3YqdXT7RCoFERDHirBwcJdH2eock0B\n"
    b"MH0pHLFnHWuBgdnwYfFNlQZPdc8YWZ0UBikStbMvU7iGS8r2qj9gXFFW7YKVEG/7\n"
    b"Qi/UOFK3WPSYjNNmYZ1EKXiv\n"
    b"-----END PRIVATE KEY-----\n"
)

TEST_PRIVATE_KEY = serialization.load_pem_private_key(FIXED_PEM, password=None)
TEST_PUBLIC_KEY = TEST_PRIVATE_KEY.public_key()


def ensure_jwks_configured():
    jwks_manager._keys[TEST_KID] = TEST_PUBLIC_KEY
    jwks_manager._last_fetched = time.time() + 999999


ensure_jwks_configured()


def create_test_jwt(
    sub: str = "test-user-uuid",
    email: str = "user@example.com",
    role: str = "authenticated",
    exp_delta: int = 3600,
    kid: str = TEST_KID,
    iss: str = None,
    aud: str = None,
) -> str:
    ensure_jwks_configured()
    now = int(time.time())
    payload = {
        "sub": sub,
        "email": email,
        "role": role,
        "iat": now,
        "exp": now + exp_delta,
        "aud": aud if aud is not None else settings.SUPABASE_JWT_AUDIENCE,
        "iss": iss if iss is not None else settings.jwt_issuer,
    }
    headers = {"kid": kid, "alg": "RS256"}
    return jwt.encode(payload, FIXED_PEM, algorithm="RS256", headers=headers)


@pytest.fixture(autouse=True)
def setup_jwks():
    ensure_jwks_configured()


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def valid_token():
    return create_test_jwt(sub="user-123", email="user123@example.com")


@pytest.fixture
def expired_token():
    return create_test_jwt(sub="user-123", exp_delta=-3600)


@pytest.fixture
def invalid_audience_token():
    return create_test_jwt(sub="user-123", aud="wrong-audience")
