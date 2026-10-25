"""Original identity must establish a transfer before any SQL evidence is built."""
from copy import deepcopy
from datetime import date
from decimal import Decimal
import unittest

from lts_v336_workbook_transfers import resolve


class OriginalTransferIdentity(unittest.TestCase):
    def setUp(self):
        serial = str((date(2020, 1, 2)-date(1899, 12, 30)).days)
        self.workbook = {'source_sha256': 'a'*64, 'ledger_rows': [
            {'row': 10, 'cells': {'A10': 'Transferência Itaú para Bradesco',
                                 'B10': '25', 'C10': serial, 'G10': 'Transferência Bancária'}}]}
        self.source = [{'idx': 1, 'dados': {'dia': '2020-01-02', 'desc': 'Transferência Itaú para Bradesco',
                                          'valor': 25, 'efeito': 'saida', 'conta': 'Itaú'}}]
        self.effective = [{'source_ref': 'evento_base:1', 'account': 'Itaú',
                           'description': 'Transferência Itaú para Bradesco', 'signed_amount': '-25'}]

    def result(self):
        return resolve(self.workbook, self.source, self.effective)

    def test_explicit_magnitude_and_existing_outgoing_leg(self):
        result = self.result()
        self.assertEqual(len(result['matched']), 1)
        self.assertEqual(Decimal(result['matched'][0]['signed_amount']), Decimal('-25'))
        self.assertEqual(self.source[0]['dados']['valor'], 25)

    def test_duplicate_original_identity_is_unresolved(self):
        self.workbook['ledger_rows'].append(deepcopy(self.workbook['ledger_rows'][0]))
        self.assertEqual(len(self.result()['matched']), 0)

    def test_original_category_is_required(self):
        self.workbook['ledger_rows'][0]['cells']['G10'] = 'Presentes'
        self.assertEqual(len(self.result()['matched']), 0)

    def test_original_negative_exception_is_preserved(self):
        self.workbook['ledger_rows'][0]['cells']['B10'] = '-25'
        self.assertEqual(len(self.result()['matched']), 0)

    def test_source_direction_must_agree(self):
        self.source[0]['dados']['efeito'] = 'entrada'
        self.assertEqual(len(self.result()['matched']), 0)

    def test_effective_bank_must_agree(self):
        self.effective[0]['account'] = 'C6'
        self.assertEqual(len(self.result()['matched']), 0)

    def test_effective_amount_must_agree(self):
        self.effective[0]['signed_amount'] = '-26'
        self.assertEqual(len(self.result()['matched']), 0)

    def test_same_amount_and_date_without_original_description_is_insufficient(self):
        self.workbook['ledger_rows'][0]['cells']['A10'] = 'Third-party transfer'
        self.assertEqual(len(self.result()['matched']), 0)

    def test_missing_existing_leg_is_not_created(self):
        self.effective.clear()
        self.assertEqual(len(self.result()['matched']), 0)

    def test_binary_excel_fraction_is_only_currency_representation(self):
        self.workbook['ledger_rows'][0]['cells']['B10'] = '25.000000000000006'
        self.assertEqual(len(self.result()['matched']), 1)
        self.assertEqual(self.result()['matched'][0]['workbook']['cells']['B10'], '25.000000000000006')

    def test_real_subcent_disagreement_is_unresolved(self):
        self.workbook['ledger_rows'][0]['cells']['B10'] = '25.001'
        self.assertEqual(len(self.result()['matched']), 0)


if __name__ == '__main__':
    unittest.main()
