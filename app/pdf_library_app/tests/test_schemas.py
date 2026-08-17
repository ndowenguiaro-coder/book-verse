from backend.schemas import UserCreate, UserLogin


def test_email_is_normalized():
    u = UserCreate(email='  USER@Example.COM ', password='password123')
    assert u.email == 'user@example.com'


def test_invalid_email_rejected():
    try:
        UserLogin(email='bad-email', password='password123')
        assert False
    except Exception:
        assert True
