module protocol::ticket_accesses {

    use protocol::ticket_issuer_policy::{Self, TicketIssuerPolicy};
    use protocol::error;
    use protocol::version::{Self, Version};

    struct TicketForFlashLoanFeeDiscount has drop {
        numerator: u64,
        denominator: u64,
    }

    struct TicketForBorrowFeeDiscount has drop {
        numerator: u64,
        denominator: u64,
    }

    public fun get_flash_loan_fee_discount(ticket: &TicketForFlashLoanFeeDiscount): (u64, u64) {
        (ticket.numerator, ticket.denominator)
    }

    public fun issue_ticket_for_flash_loan_fee_discount<Witness: drop>(
        version: &Version,
        ticket_issuer_policy: &TicketIssuerPolicy,
        witness: Witness,
        numerator: u64,
        denominator: u64,
    ): TicketForFlashLoanFeeDiscount {
        version::assert_current_version(version);
        assert!(ticket_issuer_policy::is_witness_can_issue_ticket<TicketForFlashLoanFeeDiscount, Witness>(ticket_issuer_policy, &witness), error::witness_cant_issue_ticket());

        assert!(numerator <= denominator, error::numerator_cant_be_greater_than_denominator());

        TicketForFlashLoanFeeDiscount {
            numerator,
            denominator,
        }
    }

    public fun get_borrowing_fee_discount(ticket: &TicketForBorrowFeeDiscount): (u64, u64) {
        (ticket.numerator, ticket.denominator)
    }

    public fun issue_ticket_for_borrowing_fee_discount<Witness: drop>(
        version: &Version,
        ticket_issuer_policy: &TicketIssuerPolicy,
        witness: Witness,
        numerator: u64,
        denominator: u64,
    ): TicketForBorrowFeeDiscount {
        version::assert_current_version(version);
        assert!(ticket_issuer_policy::is_witness_can_issue_ticket<TicketForBorrowFeeDiscount, Witness>(ticket_issuer_policy, &witness), error::witness_cant_issue_ticket());

        assert!(numerator <= denominator, error::numerator_cant_be_greater_than_denominator());

        TicketForBorrowFeeDiscount {
            numerator,
            denominator,
        }
    }
}