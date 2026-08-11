from agents.generation.mcp import server


class _Response:
    def raise_for_status(self) -> None:
        return None

    def json(self) -> dict:
        return {"verdict": "correct"}


def test_verify_proof_service_uses_environment_endpoint(monkeypatch) -> None:
    calls = []

    def post(endpoint: str, **kwargs):
        calls.append((endpoint, kwargs))
        return _Response()

    monkeypatch.setenv("VERIFY_PROOF_URL", "http://127.0.0.1:18091/verify")
    monkeypatch.setattr(server.requests, "post", post)

    result = server.verify_proof_service("P", "proof")

    assert calls[0][0] == "http://127.0.0.1:18091/verify"
    assert result["endpoint"] == "http://127.0.0.1:18091/verify"


def test_verify_proof_service_uses_default_endpoint(monkeypatch) -> None:
    calls = []

    def post(endpoint: str, **kwargs):
        calls.append((endpoint, kwargs))
        return _Response()

    monkeypatch.delenv("VERIFY_PROOF_URL", raising=False)
    monkeypatch.setattr(server.requests, "post", post)

    result = server.verify_proof_service("P", "proof")

    assert calls[0][0] == "http://127.0.0.1:8091/verify"
    assert result["endpoint"] == "http://127.0.0.1:8091/verify"


def test_verify_proof_service_prefers_explicit_endpoint(monkeypatch) -> None:
    calls = []

    def post(endpoint: str, **kwargs):
        calls.append((endpoint, kwargs))
        return _Response()

    monkeypatch.setenv("VERIFY_PROOF_URL", "http://127.0.0.1:18091/verify")
    monkeypatch.setattr(server.requests, "post", post)

    result = server.verify_proof_service(
        "P",
        "proof",
        endpoint="http://127.0.0.1:28091/verify",
    )

    assert calls[0][0] == "http://127.0.0.1:28091/verify"
    assert result["endpoint"] == "http://127.0.0.1:28091/verify"
