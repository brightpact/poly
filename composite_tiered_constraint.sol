pragma solidity ^0.4.19;

import './constraint.sol';
import './poly.sol';

contract CompositeTieredConstraint is Constraint {
  address admin;
  address poly;
  bool locked = false;

  Constraint[] public constraints;
  uint32 numAdded = 0;

  modifier adminOnly() {
    require(msg.sender == admin);
    _;
  }

  modifier polyOnly() {
    require(msg.sender == poly);
    _;
  }

  modifier lockedOnly() {
    require(locked);
    _;
  }

  modifier unlockedOnly() {
    require(!locked);
    _;
  }

  function CompositeTieredConstraint(
      Poly _poly,
      uint32 _totalTiers)
      public {
    admin = msg.sender;
    poly = _poly;
    constraints.length = _totalTiers;
  }

  function add(
      uint32 _tiersRequired,
      Constraint _constraint)
      adminOnly
      unlockedOnly
      external {
    uint32 i = getConstraintIndex(_tiersRequired);
    require(constraints[i] == address(0));
    constraints[i] = _constraint;
    numAdded++;
  }

  function lock()
      unlockedOnly
      adminOnly
      external {
    require(numAdded == constraints.length);
    locked = true;
  }

  function allowWithdrawal(
      uint32 /* _numTotalTiers */,
      uint32 _numApprovedTiers,
      Erc20Token _token,
      address _recipient,
      uint256 _amount)
      external
      lockedOnly
      view
      returns (bool allowed) {
    uint32 i = getConstraintIndex(_numApprovedTiers);
    Constraint constraint = constraints[i];
    return constraint.allowWithdrawal(
        _numApprovedTiers,
        _numApprovedTiers,
        _token,
        _recipient,
        _amount);
  }

  function markWithdrawal(
      uint32 _numApprovedTiers,
      Erc20Token _token,
      uint256 _amount)
      external
      polyOnly
      lockedOnly {
    uint32 i = getConstraintIndex(_numApprovedTiers);
    Constraint constraint = constraints[i];
    constraint.markWithdrawal(
        _numApprovedTiers,
        _token,
        _amount);
  }

  function getConstraintIndex(
      uint32 _numTiers)
      private
      view
      returns (uint32) {
    return min(_numTiers - 1, uint32(constraints.length) - 1);
  }

  function min(
      uint32 a,
      uint32 b)
      private
      pure
      returns (uint32) {
    return a < b ? a : b;
  }
}
