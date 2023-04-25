module switchboard::job {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{TxContext};
    use std::hash;

    struct Job has key {
        id: UID,
        name: vector<u8>,
        hash: vector<u8>,
        data: vector<u8>,
        created_at: u64,
    }

    public fun hash(job: &Job): vector<u8> {
        job.hash
    }

    public fun new(
        name: vector<u8>,
        data: vector<u8>,
        created_at: u64,
        ctx: &mut TxContext,
    ): Job {
        Job {
            id: object::new(ctx),
            name,
            hash: hash::sha3_256(data),
            created_at,
            data,
        }
    }
    
    public fun job_address(job: &Job): address {
        object::uid_to_address(&job.id)
    }

    public fun freeze_job(job: Job) {
        transfer::freeze_object(job);
    }
}
