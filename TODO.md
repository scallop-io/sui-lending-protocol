- Refactor stake reward calculate logic, use dedicated data structure for recording stake reward info, instead of put it directly in pool and check.
- Start implementing the frontend logic of the staking.
- Refactor the interest calculation logic

# Feature
- Implement flashloans
- Add reward for borrowing and lending


# Safety consideration
- Implement imergency mechanism: something like https://blog.openzeppelin.com/introducing-sentinels/
- the calculated borrow balance is always rounded up instead of being truncated.
- having a separate recipient role for reserves



# Reference metarial

Use this to document the safety of the protocol
https://blog.openzeppelin.com/compound-audit/


# Optimization
