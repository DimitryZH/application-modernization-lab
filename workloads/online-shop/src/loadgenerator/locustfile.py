#!/usr/bin/python
#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import random
from locust import FastHttpUser, TaskSet, between, events
import telemetry
from opentelemetry import propagate
from opentelemetry.trace import SpanKind


@events.init.add_listener
def init_telemetry(**kwargs):
    import grpc.experimental.gevent

    grpc.experimental.gevent.init_gevent()
    telemetry.init()


@events.quitting.add_listener
def shutdown_telemetry(**kwargs):
    telemetry.shutdown()


def request(l, method, path, data=None, **kwargs):
    route = "/product/{id}" if path.startswith("/product/") else path
    with telemetry.operation(method + " " + route, SpanKind.CLIENT) as span:
        headers = dict(kwargs.pop("headers", {}))
        propagate.inject(headers)
        response = l.client.request(method, path, data=data, name=route, headers=headers, **kwargs)
        span.set_attribute("http.response.status_code", response.status_code)
        if response.status_code >= 400 or response.status_code == 0:
            span.set_status(telemetry.Status(telemetry.StatusCode.ERROR, "http failed"))
        return response


from faker import Faker
import datetime

fake = Faker()

products = [
    "0PUK6V6EV0",
    "1YMWWN1N4O",
    "2ZYFJ3GM2N",
    "66VCHSJNUP",
    "6E92ZMYYFZ",
    "9SIQT8TOJO",
    "L9ECAV7KIM",
    "LS4PSXUNUM",
    "OLJCESPC7Z",
]


def index(l):
    request(l, "GET", "/")


def setCurrency(l):
    currencies = ["EUR", "USD", "JPY", "CAD", "GBP", "TRY"]
    request(l, "POST", "/setCurrency", {"currency_code": random.choice(currencies)})


def browseProduct(l):
    request(l, "GET", "/product/" + random.choice(products))


def viewCart(l):
    request(l, "GET", "/cart")


def addToCart(l):
    product = random.choice(products)
    request(l, "GET", "/product/" + product)
    request(
        l, "POST", "/cart", {"product_id": product, "quantity": random.randint(1, 10)}
    )


def empty_cart(l):
    request(l, "POST", "/cart/empty")


def checkout(l):
    addToCart(l)
    current_year = datetime.datetime.now().year + 1
    request(
        l,
        "POST",
        "/cart/checkout",
        {
            "email": fake.email(),
            "street_address": fake.street_address(),
            "zip_code": fake.zipcode(),
            "city": fake.city(),
            "state": fake.state_abbr(),
            "country": fake.country(),
            "credit_card_number": fake.credit_card_number(card_type="visa"),
            "credit_card_expiration_month": random.randint(1, 12),
            "credit_card_expiration_year": random.randint(
                current_year, current_year + 70
            ),
            "credit_card_cvv": f"{random.randint(100, 999)}",
        },
    )


def logout(l):
    request(l, "GET", "/logout")


class UserBehavior(TaskSet):

    def on_start(self):
        index(self)

    tasks = {
        index: 1,
        setCurrency: 2,
        browseProduct: 10,
        addToCart: 2,
        viewCart: 3,
        checkout: 1,
    }


class WebsiteUser(FastHttpUser):
    tasks = [UserBehavior]
    wait_time = between(1, 10)
