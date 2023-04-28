module switchboard::errors {
    public fun Generic(): u64 { 0 }
    public fun InvalidAuthority(): u64 { 1 }
    public fun PermissionDenied(): u64 { 2 }
    public fun CrankDisabled(): u64 { 3 }
    public fun JobsChecksumMismatch(): u64 { 4 }
    public fun InvalidArgument(): u64 { 5 }
    public fun AggregatorLocked(): u64 { 6 }
    public fun InsufficientCoin(): u64 { 7 }
    public fun AggregatorInvalidBatchSize(): u64 { 8 }
    public fun AggregatorInvalidMinOracleResults(): u64 { 9 }
    public fun AggregatorInvalidUpdateDelay(): u64 { 10 }
    public fun AggregatorIllegalRoundOpenCall(): u64 { 11 }
    public fun AggregatorInvalidMinJobs(): u64 { 12 }
    public fun InvalidQuoteError(): u64 { 13 }
    public fun QuoteExpiredError(): u64 { 14 } 
    public fun InvalidNodeError(): u64 { 15 }
    public fun QueueFullError(): u64 { 16 }
    public fun InsufficientQueueError(): u64 { 17 }
    public fun MrEnclaveAlreadyExists(): u64 { 18 }
    public fun MrEnclaveDoesNotExist(): u64 { 19 }
    public fun MrEnclaveAtCapacity(): u64 { 20 }
    public fun InvalidConstraint(): u64 { 21 }
    public fun InvalidTimestamp(): u64 { 22 }
    public fun InvalidPackage(): u64 { 23 }
}
