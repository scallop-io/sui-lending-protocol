module protocol_test::open_position_t {
  
  #[test_only]
  use protocol::position::{PositionKey, Position};
  #[test_only]
  use protocol::open_position::open_position;
  #[test_only]
  use sui::test_scenario::Scenario;
  #[test_only]
  use sui::test_scenario;
  
  #[test_only]
  public fun open_position_t(senario: &mut Scenario, user: address): (Position, PositionKey) {
    test_scenario::next_tx(senario, user);
    open_position(test_scenario::ctx(senario));
    test_scenario::next_tx(senario, user);
    let position = test_scenario::take_shared<Position>(senario);
    let positionKey = test_scenario::take_from_sender<PositionKey>(senario);
    (position, positionKey)
  }
}
