# Choose the same payable cycle in the rendered interface

An unsorted incoming cycle array could make the invoice panel show December first while the canonical operating model correctly selected November. Select payable cycles without mutating the source: retain unknown amounts, exclude explicit settlement and zero/credit totals, then sort by reference month and due date. Use that order for each card and the following-cycle totals.

The shared Dashboard/invoice panel also shows the oldest known unsettled target across cards. It retains past and partial cycles and labels the displayed number as the cycle total. A reported partial payment does not invent an outstanding balance. Existing links open the exact original cycle and composition; Flow keeps the same identity contract.

The new immutable release is V356, based on V353. Financial sources, API writers, raw cycles, expense presentation and other screens are preserved. PostgreSQL-produced synthetic projections must match the first rendered card row and global target, including deliberately unsorted input, rollover, explicit payment, zero and credit cycles. Inspect the actual card panel in desktop/mobile captures and verify all served files after publication. Private HTTP-session and physical-device acceptance remain separate.
