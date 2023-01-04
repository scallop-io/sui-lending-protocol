#[test_only]
module protocol_test::open_position_t {
  
  use protocol::position::{PositionKey, Position};
  use protocol::open_position::open_position;
  use sui::test_scenario::Scenario;
  use sui::test_scenario;
  
  public fun open_position_t(senario: &mut Scenario, user: address): (Position, PositionKey) {
    test_scenario::next_tx(senario, user);
    open_position(test_scenario::ctx(senario));
    test_scenario::next_tx(senario, user);
    let position = test_scenario::take_shared<Position>(senario);
    let positionKey = test_scenario::take_from_sender<PositionKey>(senario);
    (position, positionKey)
  }
}
