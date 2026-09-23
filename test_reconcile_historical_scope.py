import copy
import datetime as dt
import unittest
from decimal import Decimal
from audit_original_daily_balances import EXCEL_EPOCH
from reconcile_historical_scope import reconcile


class BoundedHistoryTests(unittest.TestCase):
    def setUp(self):
        self.boundary = dt.date(2026, 7, 8)
        self.specs = [('Bank', 5, 7, 53, 165, '2026-07-06')]
        self.rows = {3: {}, 5: {}, 7: {}, 53: {}, 165: {}}
        for col, day in enumerate([dt.date(2026, 7, d) for d in (6, 7, 8)], 1):
            self.rows[3][col] = (str((day-EXCEL_EPOCH).days), None)
            for row, value in [(5, 100), (7, 20), (53, 20), (165, 100)]:
                self.rows[row][col] = (str(value), None)
        self.ledger = {'from':'2026-07-06','through':'2026-07-07','accounts':[
            {'account':'Bank','daily':[['2026-07-06',0,20,20],['2026-07-07',0,20,20]]}]}

    def run_comparison(self):
        return reconcile(self.rows,self.specs,self.ledger,self.boundary)

    def test_preservation_and_bounded_match(self):
        before = copy.deepcopy((self.rows,self.ledger))
        result = self.run_comparison()
        self.assertEqual(result['accounts']['Bank']['compared_days'],2)
        self.assertEqual(result['accounts']['Bank']['stop_reason'],'account_activity_boundary')
        self.assertFalse(result['financial_rows_changed'])
        self.assertEqual(before,(self.rows,self.ledger))

    def test_gross_mismatch_cannot_hide_behind_zero_net(self):
        self.ledger['accounts'][0]['daily'][0] = ['2026-07-06',0,0,0]
        result = self.run_comparison()['accounts']['Bank']
        self.assertEqual(result['compared_days'],1)
        self.assertEqual(result['stop_reason'],'income_source_difference')

    def test_invalid_date_stops_without_inventing_calendar(self):
        self.rows[3][1] = ('#NAME?','e')
        result = self.run_comparison()['accounts']['Bank']
        self.assertEqual(result['compared_days'],1)
        self.assertEqual(result['stop_reason'],'missing_or_ambiguous_source_date')

    def test_duplicate_date_fails_closed(self):
        self.rows[3][4] = self.rows[3][2]
        self.assertEqual(self.run_comparison()['accounts']['Bank']['compared_days'],0)

    def test_operational_event_is_rejected(self):
        self.ledger['accounts'][0]['daily'].append(['2026-07-08',0,20,20])
        with self.assertRaises(ValueError): self.run_comparison()

    def test_missing_anchor_stays_unavailable(self):
        self.rows[5][3] = (None,None)
        result = self.run_comparison()['accounts']['Bank']
        self.assertEqual(result['status'],'not_established')

    def test_prior_balance_jump_stops(self):
        self.rows[5][1] = ('1000',None)
        result = self.run_comparison()['accounts']['Bank']
        self.assertEqual(result['compared_days'],1)
        self.assertEqual(result['stop_reason'],'source_arithmetic')

    def test_missing_account_is_not_zero(self):
        self.ledger['accounts'] = []
        self.assertEqual(self.run_comparison()['accounts']['Bank']['compared_days'],0)


if __name__ == '__main__': unittest.main()
