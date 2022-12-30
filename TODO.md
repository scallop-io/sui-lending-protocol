- Refactor stake reward calculate logic, use dedicated data structure for recording stake reward info, instead of put it directly in pool and check.
- Start implementing the frontend logic of the staking.
- Refactor the interest calculation logic

# Feature
- Implement flashloans


# Safety consideration
- Implement imergency mechanism: something like https://blog.openzeppelin.com/introducing-sentinels/
- the calculated borrow balance is always rounded up instead of being truncated.
- having a separate recipient role for reserves
- Set a minimum borrow amount for each token



# Reference metarial

Use this to document the safety of the protocol
https://blog.openzeppelin.com/compound-audit/


# Optimization
1. 包名称，函数名，变量名过长，需要简短
2. 清算逻辑，计算过程步骤多，拆分简化