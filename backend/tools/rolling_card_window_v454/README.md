# Rolling card spending window

An optional integer `lead_months` on a dated new-spending provision makes the
first eligible month the later of its original start and the as-of calendar
month plus that lead. Near months retain only their existing obligations;
they emit no historical allowance or new-spending event. The fixed provision
is added once from the eligible month onward. Original obligations, their
source references, unknown-data guards and other series remain unchanged.

The calculator uses its explicit as-of date, including December/year and leap
boundaries. It does not rely on a one-time mutation of a fixed start date.
The existing producer manifest pins both revised definitions. Installation
and rollback preserve original permissions and attributes and reject drift.
Policy activation is a separate owner-scoped, version-guarded operation.

V454 derives from the immutable V451 release. Its assumptions explain the
rolling window; spending forecasts have a distinct label from known invoices.
The synthetic tests do not certify an authenticated session or a physical phone.
