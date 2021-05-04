import time
import ipaddress
import random
import string
from locust import HttpUser, task, between
from locust.contrib.fasthttp import FastHttpUser

ip_number = int(ipaddress.IPv4Address("100.0.0.1"))

class CheckStatus(FastHttpUser):
    wait_time = between(1, 2)

    @task
    def latest_page(self):
        random_string = ''.join(random.choice(string.ascii_letters) for i in range(10))
        self.client.get("/search?q=" + random_string, headers={"X-Forwarded-For": self.fake_ip})
    def on_start(self):
        global ip_number
        ip_number += 1
        self.fake_ip = str(ipaddress.IPv4Address(ip_number))

