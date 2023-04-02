module protocol::limiter {
    use std::vector;

    const EOutflowReachedLimit: u64 = 0x10000;

    /// One cycle equal to 24 hours in second
    const ONE_CYCLE_IN_SECOND: u32 = 60 * 60 * 24;

    struct Limiter has store, drop {
        outflow_limit: u64,
        /// how long is one segment in seconds
        outflow_segment_duration: u32,
        outflow_segments: vector<Segment>,
    }

    struct Segment has store, drop {
        index: u64,
        value: u64
    }

    public fun new(
        outflow_limit: u64,
        outflow_segment_duration: u32,
    ): Limiter {
        let vec_segments = vector::empty();

        let (i, len) = (0, ONE_CYCLE_IN_SECOND / outflow_segment_duration);
        while (i < len) {
            vector::push_back(&mut vec_segments, Segment {
                index: (i as u64),
                value: 0,
            });

            i = i + 1;
        };

        Limiter {
            outflow_limit: outflow_limit,
            outflow_segment_duration: outflow_segment_duration,
            outflow_segments: vec_segments,
        }
    }

    public fun update_outflow_limiter(
        self: &mut Limiter,
        now: u64,
        value: u64,
    ) {
        let curr_outflow = count_current_outflow(self, now);
        assert!(curr_outflow + value <= self.outflow_limit, EOutflowReachedLimit);

        let timestamp_index = now / (self.outflow_segment_duration as u64);
        let curr_index = timestamp_index % vector::length(&self.outflow_segments);
        let segment = vector::borrow_mut<Segment>(&mut self.outflow_segments, curr_index);
        if (segment.index != timestamp_index) {
            segment.index = timestamp_index;
            segment.value = 0;
        };
        segment.value = segment.value + value;
    }

    public fun count_current_outflow(
        self: &Limiter,
        now: u64,
    ): u64 {
        let curr_outflow: u64 = 0;
        let timestamp_index = now / (self.outflow_segment_duration as u64);

        let (i, len) = (0, vector::length(&self.outflow_segments));
        while (i < len) {
            let segment = vector::borrow<Segment>(&self.outflow_segments, i);
            if ((len > timestamp_index) || (segment.index >= (timestamp_index - len + 1))) {
                curr_outflow = curr_outflow + segment.value;
            };
            i = i + 1;
        };

        curr_outflow
    }

    #[test]
    fun outflow_limit_test() {
        let segment_duration: u64 = 60 * 30;
        let segment_count = (ONE_CYCLE_IN_SECOND as u64) / segment_duration;

        let limiter = new(segment_count * 100, (segment_duration as u32));
        let mock_timestamp = 100;

        let i = 0;
        while (i < segment_count) {
            mock_timestamp = mock_timestamp + segment_duration;
            update_outflow_limiter(&mut limiter, mock_timestamp, 100);
            i = i + 1;
        };

        // updating the timestamp here clearing the very first segment that we filled last time
        // hence the outflow limiter wouldn't throw an error because it satisfy the limit
        mock_timestamp = mock_timestamp + segment_duration;
        update_outflow_limiter(&mut limiter, mock_timestamp, 100);
    }

    #[test, expected_failure(abort_code = EOutflowReachedLimit)]
    fun outflow_limit_test_failed_reached_limit() {
        let segment_duration: u64 = 60 * 30;
        let limiter = new(10000, (segment_duration as u32));
        let mock_timestamp = 1000;

        update_outflow_limiter(&mut limiter, mock_timestamp, 5000);
        mock_timestamp = mock_timestamp + segment_duration;
        update_outflow_limiter(&mut limiter, mock_timestamp, 3000);
        mock_timestamp = mock_timestamp + segment_duration;
        update_outflow_limiter(&mut limiter, mock_timestamp, 2001);
    }
}