"""Assertions against built images. Any failed assertion exits nonzero."""

import concurrent.futures, json, os, pathlib, sys, time, uuid, datetime
import grpc, requests
from grpc_tools import protoc

assert (
    protoc.main(
        [
            "protoc",
            "-I/protos",
            "--python_out=/tmp",
            "--grpc_python_out=/tmp",
            "/protos/demo.proto",
        ]
    )
    == 0
)
sys.path.insert(0, "/tmp")
import demo_pb2 as pb, demo_pb2_grpc as rpc

BASE = "http://frontend:8080"
FAULTS = "http://faults:8081"
evidence = {"requests": [], "rpc_cases": [], "checks": []}


def headers(label, sampled=True):
    trace = uuid.uuid4().hex
    parent = uuid.uuid4().hex[:16]
    evidence["requests"].append(
        {"label": label, "trace_id": trace, "parent_id": parent, "sampled": sampled}
    )
    return {"traceparent": f"00-{trace}-{parent}-" + ("01" if sampled else "00")}


def check(name):
    evidence["checks"].append(name)
    print("PASS", name, flush=True)


def fixture(method="", code=None, delay=None):
    data = {"method": method}
    if code:
        data["code"] = code
    if delay:
        data["delay"] = delay
    requests.post(FAULTS + "/mode", json=data, timeout=5).raise_for_status()


def shopping(label="checkout", expect_success=True):
    s = requests.Session()
    h = headers(label)
    r = s.get(BASE + "/", headers=h, timeout=20)
    assert r.status_code == 200 and "Online Shop" in r.text
    r = s.get(BASE + "/product/0PUK6V6EV0", timeout=20)
    assert r.status_code == 200 and "Candle" in r.text
    r = s.post(
        BASE + "/cart", data={"product_id": "0PUK6V6EV0", "quantity": 2}, timeout=20
    )
    assert r.status_code == 200
    r = s.get(BASE + "/cart", timeout=20)
    assert r.status_code == 200 and "Candle" in r.text
    form = {
        "email": "privacy-canary@example.invalid",
        "street_address": "PrivacyCanaryStreet",
        "zip_code": "10004",
        "city": "PrivacyCanaryCity",
        "state": "PrivacyCanaryState",
        "country": "PrivacyCanaryCountry",
        "credit_card_number": "4111111111111111",
        "credit_card_expiration_month": "12",
        "credit_card_expiration_year": str(datetime.date.today().year + 2),
        "credit_card_cvv": "789",
    }
    h = headers(label + ".submit")
    r = s.post(BASE + "/cart/checkout", data=form, headers=h, timeout=20)
    assert (r.status_code == 200) == expect_success, (
        label,
        r.status_code,
        r.text[:100],
    )
    user = s.cookies.get("shop_session-id")
    cart = rpc.CartServiceStub(grpc.insecure_channel("cartservice:7070")).GetCart(
        pb.GetCartRequest(user_id=user), timeout=5
    )
    if expect_success and label != "cart-clear-failure":
        assert len(cart.items) == 0
    if not expect_success or label == "cart-clear-failure":
        assert len(cart.items) == 1 and cart.items[0].quantity == 2
    if expect_success:
        assert "confirmation" in r.text.lower() or "order" in r.text.lower()
    check(label)
    return h


def coverage():
    # Construct reserved-field protobuf via dictionary.
    specifications = [
        (
            "cartservice:7070",
            rpc.CartServiceStub,
            "AddItem",
            pb.AddItemRequest(
                user_id="probe", item=pb.CartItem(product_id="0PUK6V6EV0", quantity=1)
            ),
        ),
        (
            "cartservice:7070",
            rpc.CartServiceStub,
            "GetCart",
            pb.GetCartRequest(user_id="probe"),
        ),
        (
            "cartservice:7070",
            rpc.CartServiceStub,
            "EmptyCart",
            pb.EmptyCartRequest(user_id="probe"),
        ),
        (
            "productcatalogservice:3550",
            rpc.ProductCatalogServiceStub,
            "ListProducts",
            pb.Empty(),
        ),
        (
            "productcatalogservice:3550",
            rpc.ProductCatalogServiceStub,
            "GetProduct",
            pb.GetProductRequest(id="0PUK6V6EV0"),
        ),
        (
            "productcatalogservice:3550",
            rpc.ProductCatalogServiceStub,
            "SearchProducts",
            pb.SearchProductsRequest(query="candle"),
        ),
        (
            "shippingservice:50051",
            rpc.ShippingServiceStub,
            "GetQuote",
            pb.GetQuoteRequest(),
        ),
        (
            "shippingservice:50051",
            rpc.ShippingServiceStub,
            "ShipOrder",
            pb.ShipOrderRequest(
                address=pb.Address(
                    street_address="PrivacyCanaryStreet",
                    city="PrivacyCanaryCity",
                    state="PrivacyCanaryState",
                )
            ),
        ),
        (
            "currencyservice:7000",
            rpc.CurrencyServiceStub,
            "GetSupportedCurrencies",
            pb.Empty(),
        ),
        (
            "currencyservice:7000",
            rpc.CurrencyServiceStub,
            "Convert",
            pb.CurrencyConversionRequest(
                **{"from": pb.Money(currency_code="USD", units=10), "to_code": "EUR"}
            ),
        ),
        (
            "paymentservice:50051",
            rpc.PaymentServiceStub,
            "Charge",
            pb.ChargeRequest(
                amount=pb.Money(currency_code="USD", units=10),
                credit_card=pb.CreditCardInfo(
                    credit_card_number="4111111111111111",
                    credit_card_expiration_month=12,
                    credit_card_expiration_year=datetime.date.today().year + 2,
                ),
            ),
        ),
        (
            "emailservice:8080",
            rpc.EmailServiceStub,
            "SendOrderConfirmation",
            pb.SendOrderConfirmationRequest(email="privacy-canary@example.invalid"),
        ),
        (
            "recommendationservice:8080",
            rpc.RecommendationServiceStub,
            "ListRecommendations",
            pb.ListRecommendationsRequest(product_ids=["0PUK6V6EV0"]),
        ),
        (
            "adservice:9555",
            rpc.AdServiceStub,
            "GetAds",
            pb.AdRequest(context_keys=["unknown-canary"]),
        ),
    ]
    for address, cls, method, request in specifications:
        h = headers("rpc." + method)
        response = getattr(cls(grpc.insecure_channel(address)), method)(
            request, metadata=list(h.items()), timeout=10
        )
        if method == "SearchProducts":
            assert len(response.results) > 0
        if method == "ListRecommendations":
            assert "0PUK6V6EV0" not in response.product_ids
        evidence["rpc_cases"].append(
            {
                "trace_id": evidence["requests"][-1]["trace_id"],
                "method": method,
                "service": address.split(":")[0],
            }
        )
    check("direct RPC coverage")


def failures():
    for method, label, success in [
        ("PaymentService/Charge", "payment-failure", False),
        ("ShippingService/ShipOrder", "shipping-failure", False),
        ("EmailService/SendOrderConfirmation", "email-failure", True),
        ("CartService/EmptyCart", "cart-clear-failure", True),
    ]:
        fixture("/hipstershop." + method, "UNAVAILABLE")
        shopping(label, success)
        fixture()
    fixture("/hipstershop.AdService/GetAds", delay=0.2)
    assert (
        requests.get(BASE + "/", headers=headers("ad-timeout"), timeout=20).status_code
        == 200
    )
    fixture()
    check("ad timeout fallback")
    fixture("/hipstershop.RecommendationService/ListRecommendations", "UNAVAILABLE")
    assert (
        requests.get(
            BASE + "/product/0PUK6V6EV0",
            headers=headers("recommendation-failure"),
            timeout=20,
        ).status_code
        == 200
    )
    fixture()
    check("recommendation fallback")
    catalog = rpc.ProductCatalogServiceStub(
        grpc.insecure_channel("productcatalogservice:3550")
    )
    try:
        catalog.GetProduct(
            pb.GetProductRequest(id="missing-canary"),
            metadata=list(headers("not-found").items()),
            timeout=5,
        )
        raise AssertionError("expected NOT_FOUND")
    except grpc.RpcError as e:
        assert e.code() == grpc.StatusCode.NOT_FOUND
    assert not catalog.SearchProducts(
        pb.SearchProductsRequest(query="missing-canary"), timeout=5
    ).results
    payment = rpc.PaymentServiceStub(grpc.insecure_channel("paymentservice:50051"))
    for number, year in [
        ("4111111111111111", 2020),
        ("invalid-canary", 2030),
        ("378282246310005", 2030),
    ]:
        try:
            payment.Charge(
                pb.ChargeRequest(
                    credit_card=pb.CreditCardInfo(
                        credit_card_number=number,
                        credit_card_expiration_month=1,
                        credit_card_expiration_year=year,
                    )
                ),
                metadata=list(headers("payment-rejection").items()),
                timeout=5,
            )
            raise AssertionError("expected rejection")
        except grpc.RpcError:
            pass
    check("deterministic error RPCs")
    fixture("/hipstershop.ProductCatalogService/ListProducts", delay=0.2)
    stub = rpc.RecommendationServiceStub(
        grpc.insecure_channel("recommendationservice:8080")
    )
    try:
        stub.ListRecommendations(
            pb.ListRecommendationsRequest(),
            metadata=list(headers("deadline").items()),
            timeout=0.02,
        )
        raise AssertionError("deadline expected")
    except grpc.RpcError as e:
        assert e.code() == grpc.StatusCode.DEADLINE_EXCEEDED
    fixture()
    check("deadline")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "full"
    if mode != "redis":
        for _ in range(60):
            try:
                if requests.get(BASE + "/", timeout=3).status_code == 200:
                    break
            except requests.RequestException:
                pass
            time.sleep(1)
        else:
            raise AssertionError("frontend readiness timeout")
    fixture()
    if mode == "redis":
        stub = rpc.CartServiceStub(grpc.insecure_channel("cartservice:7070"))
        try:
            stub.GetCart(
                pb.GetCartRequest(user_id="redis-failure"),
                metadata=list(headers("redis-failure").items()),
                timeout=10,
            )
            raise AssertionError("storage failure expected")
        except grpc.RpcError as error:
            assert error.code() in (
                grpc.StatusCode.FAILED_PRECONDITION,
                grpc.StatusCode.DEADLINE_EXCEEDED,
            )
        check("Redis unavailable")
        pathlib.Path("/evidence/scenarios-redis.json").write_text(
            json.dumps(evidence, indent=2)
        )
        return
    shopping(mode)
    if mode == "full":
        coverage()
        failures()

        def concurrent_request(i):
            h = headers("concurrent." + str(i))
            r = requests.get(BASE + "/product/0PUK6V6EV0", headers=h, timeout=30)
            assert r.status_code == 200

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
            list(pool.map(concurrent_request, range(20)))
        check("20 concurrent requests")
        requests.get(
            BASE + "/", headers=headers("unsampled", False), timeout=20
        ).raise_for_status()
        requests.post(
            BASE + "/bot",
            json={"message": "PrivacyCanaryBody"},
            headers=headers("assistant"),
            timeout=10,
        ).raise_for_status()
        captures = requests.get(FAULTS + "/captures", timeout=5).json()
        assert any(x.get("traceparent") for x in captures)
        check("optional outbound HTTP propagation")
    pathlib.Path("/evidence/scenarios-" + mode + ".json").write_text(
        json.dumps(evidence, indent=2)
    )


if __name__ == "__main__":
    main()
