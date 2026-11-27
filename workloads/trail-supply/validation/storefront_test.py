"""Catalog/advertisement/asset consistency checks; standard library only."""
import hashlib
import json
from pathlib import Path
import re
import unittest

WORKLOAD = Path(__file__).resolve().parents[1]
STATIC = WORKLOAD / 'src/frontend/static'
APPROVED = {
    'OLJCESPC7Z': ('Summit 45L Backpack', 'packs', 129),
    '66VCHSJNUP': ('Alpine 2P Tent', 'shelter', 249),
    '1YMWWN1N4O': ('Pathfinder Headlamp', 'lighting', 35),
    'L9ECAV7KIM': ('Traverse Trekking Poles', 'hiking', 69),
    '2ZYFJ3GM2N': ('Basecamp Sleeping Bag', 'sleep', 89),
    '0PUK6V6EV0': ('Trail Lantern', 'lighting', 39),
    'LS4PSXUNUM': ('Expedition Camp Stove', 'cooking', 59),
    '9SIQT8TOJO': ('RestPoint Sleeping Pad', 'sleep', 79),
    '6E92ZMYYFZ': ('Ridge Insulated Bottle', 'hydration', 29),
}


class StorefrontConsistencyTests(unittest.TestCase):
    def test_approved_catalog_and_money(self):
        products = json.loads((WORKLOAD / 'src/productcatalogservice/products.json').read_text(encoding='utf-8'))['products']
        self.assertEqual(len(products), 9)
        self.assertEqual({p['id'] for p in products}, set(APPROVED))
        for product in products:
            name, category, price = APPROVED[product['id']]
            self.assertEqual(product['name'], name)
            self.assertEqual(product['categories'], [category])
            self.assertEqual(product['priceUsd'], {'currencyCode': 'USD', 'units': price, 'nanos': 0})
            self.assertTrue(product['description'].strip())
            path = STATIC / product['picture'].removeprefix('/static/')
            self.assertTrue(path.is_file())
            self.assertEqual(path.read_bytes()[:2], b'\xff\xd8')

    def test_advertisement_references_and_categories(self):
        source = (WORKLOAD / 'src/adservice/src/main/java/hipstershop/AdService.java').read_text(encoding='utf-8')
        blocks = re.findall(r'Ad (\w+)\s*=\s*Ad\.newBuilder\(\)\s*\.setRedirectUrl\("/product/(\w+)"\)\s*\.setText\("([^"]+)"\)', source)
        self.assertEqual({identifier for _, identifier, _ in blocks}, set(APPROVED))
        self.assertEqual(len(blocks), 9)
        by_variable = {variable: identifier for variable, identifier, _ in blocks}
        mapped = set()
        for category, variables in re.findall(r'\.putAll\("(\w+)", ([^)]+)\)', source):
            for variable in variables.split(', '):
                identifier = by_variable[variable]
                self.assertEqual(APPROVED[identifier][1], category)
                mapped.add(identifier)
        self.assertEqual(mapped, set(APPROVED))
        for _, identifier, text in blocks:
            self.assertIn(APPROVED[identifier][0], text)
            self.assertNotIn('%', text)

    def test_local_asset_inventory_and_build_contract(self):
        inventory = json.loads((WORKLOAD / 'asset-inventory.json').read_text(encoding='utf-8'))
        self.assertEqual(inventory['suppliedImages'], 18)
        self.assertEqual(len(inventory['assets']), 16)
        contract = json.loads((WORKLOAD / 'build.contract.json').read_text(encoding='utf-8'))
        declared = next(c['assets'] for c in contract['components'] if c['id'] == 'frontend')
        for asset in inventory['assets']:
            path = STATIC / asset['path'].removeprefix('/static/')
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), asset['sha256'])
            self.assertEqual(path.stat().st_size, asset['finalBytes'])
            self.assertIn(path.relative_to(WORKLOAD).as_posix(), declared)
        for name in declared:
            self.assertTrue((WORKLOAD / name).is_file(), name)
        self.assertEqual((STATIC / 'favicon.ico').read_bytes()[:4], b'\0\0\x01\0')

    def test_no_external_presentation_requests_or_root_css_paths(self):
        for path in [*(WORKLOAD / 'src/frontend/templates').glob('*.html'), *STATIC.rglob('*.css')]:
            text = path.read_text(encoding='utf-8')
            self.assertNotRegex(text, r'(?:src|href)=["\']https?://(?:fonts|stackpath|cdn)')
            self.assertNotRegex(text, r'url\(["\']?/static/')
        cart = (WORKLOAD / 'src/frontend/templates/cart.html').read_text(encoding='utf-8')
        self.assertIn('<option value="12">December</option>', cart)


if __name__ == '__main__':
    unittest.main()
