"""Render-only review checks. Requires Compose v2 CLI, never a Docker engine."""
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

HERE = Path(__file__).resolve().parent
WORKLOAD = HERE.parent
sys.path.insert(0, str(WORKLOAD / 'validation/otel'))
from redis_contract import check


def render(project, prefix=''):
    env = {key: value for key, value in os.environ.items()
           if not key.startswith('COMPOSE_')}
    env.update(SOURCE_REVISION='a' * 40, FRONTEND_PORT='18081',
               BASE_URL=prefix, FRONTEND_MESSAGE='', CYMBAL_BRANDING='false', BANNER_COLOR='')
    return json.loads(subprocess.check_output(
        ['docker', 'compose', '-p', project, '-f', str(HERE / 'compose.yaml'),
         '--profile', 'load', 'config', '--format', 'json'],
        env=env, text=True, encoding='utf-8'))


class ReviewComposeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = render('trail-supply-review-static')

    def test_all_source_builds_are_workload_local(self):
        contract = json.loads((WORKLOAD / 'build.contract.json').read_text())
        self.assertEqual(set(self.model['services']),
                         {c['id'] for c in contract['components']} |
                         {'redis-cart', 'redis-data-init'})
        for component in contract['components']:
            with self.subTest(component=component['id']):
                service = self.model['services'][component['id']]
                self.assertEqual(Path(service['build']['context']).resolve(),
                                 (WORKLOAD / component['buildContext']).resolve())
                self.assertEqual(service['build']['args']['SOURCE_REVISION'], 'a' * 40)
                self.assertEqual(service['platform'], 'linux/amd64')
                self.assertTrue(service['image'].startswith('trail-supply-review-'))
                self.assertFalse(service.get('container_name'))

    def test_direct_dependencies_and_no_test_resources(self):
        services = self.model['services']
        self.assertFalse({'faults', 'probe', 'collector'} & services.keys())
        frontend = services['frontend']['environment']
        for key, endpoint in {
            'PRODUCT_CATALOG_SERVICE_ADDR': 'productcatalogservice:3550',
            'CURRENCY_SERVICE_ADDR': 'currencyservice:7000',
            'CART_SERVICE_ADDR': 'cartservice:7070',
            'RECOMMENDATION_SERVICE_ADDR': 'recommendationservice:8080',
            'SHIPPING_SERVICE_ADDR': 'shippingservice:50051',
            'CHECKOUT_SERVICE_ADDR': 'checkoutservice:5050',
            'AD_SERVICE_ADDR': 'adservice:9555',
        }.items():
            self.assertEqual(frontend[key], endpoint)
            self.assertEqual(services[endpoint.split(':')[0]]['environment']['PORT'],
                             endpoint.split(':')[1])
        checkout = services['checkoutservice']['environment']
        for key in ('SHIPPING_SERVICE_ADDR', 'PRODUCT_CATALOG_SERVICE_ADDR',
                    'CART_SERVICE_ADDR', 'CURRENCY_SERVICE_ADDR'):
            self.assertEqual(checkout[key], frontend[key])
        self.assertEqual(checkout['EMAIL_SERVICE_ADDR'], 'emailservice:8080')
        self.assertEqual(checkout['PAYMENT_SERVICE_ADDR'], 'paymentservice:50051')
        self.assertEqual(services['recommendationservice']['environment']
                         ['PRODUCT_CATALOG_SERVICE_ADDR'], 'productcatalogservice:3550')
        self.assertEqual(services['loadgenerator']['profiles'], ['load'])
        self.assertEqual(frontend['ENABLE_ASSISTANT'], 'false')
        self.assertEqual(frontend['SHOPPING_ASSISTANT_SERVICE_ADDR'], '127.0.0.1:1')
        self.assertNotIn('PACKAGING_SERVICE_URL', frontend)
        for service in services.values():
            if 'environment' in service:
                self.assertEqual(service['environment']['ONLINE_SHOP_TELEMETRY_ENABLED'], 'false')

    def test_only_storefront_is_published_to_loopback(self):
        for name, service in self.model['services'].items():
            ports = service.get('ports', [])
            if name == 'frontend':
                self.assertEqual(len(ports), 1)
                self.assertEqual(ports[0]['host_ip'], '127.0.0.1')
                self.assertEqual(str(ports[0]['published']), '18081')
                self.assertEqual(ports[0]['target'], 8080)
            else:
                self.assertFalse(ports, name)

    def test_redis_security_and_init_ownership(self):
        check(self.model)  # Reuse every inherited Redis runtime/storage guard.
        services = self.model['services']
        init = services['redis-data-init']
        self.assertEqual(init['image'], services['redis-cart']['image'])
        self.assertEqual(init['network_mode'], 'none')
        self.assertEqual(init['user'], '0:0')
        self.assertTrue(init['read_only'])
        self.assertEqual(init['cap_drop'], ['ALL'])
        self.assertEqual(init['cap_add'], ['CHOWN'])
        self.assertEqual(init['security_opt'], ['no-new-privileges:true'])
        self.assertEqual(init['entrypoint'], ['chown'])
        self.assertEqual(init['command'], ['1000:1000', '/data'])
        self.assertEqual(init['volumes'][0]['source'], 'redis-data')
        self.assertEqual(init['volumes'][0]['target'], '/data')
        self.assertEqual(services['redis-cart']['depends_on']['redis-data-init']
                         ['condition'], 'service_completed_successfully')
        self.assertEqual(services['cartservice']['depends_on']['redis-cart']
                         ['condition'], 'service_healthy')

    def test_projects_do_not_share_storage(self):
        other = render('trail-supply-review-other')
        self.assertNotEqual(self.model['volumes']['redis-data']['name'],
                            other['volumes']['redis-data']['name'])
        self.assertFalse(other['volumes']['redis-data'].get('external'))
        self.assertFalse(other['networks']['default'].get('external'))

    def test_prefix_is_forwarded_without_changing_backend_endpoints(self):
        prefixed = render('trail-supply-review-prefix', '/trail')
        environment = prefixed['services']['frontend']['environment']
        self.assertEqual(environment['BASE_URL'], '/trail')
        self.assertEqual(environment['PRODUCT_CATALOG_SERVICE_ADDR'], 'productcatalogservice:3550')


if __name__ == '__main__':
    unittest.main()
