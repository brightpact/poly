pragma solidity ^0.4.19;

import './constraint.sol';
import './erc20_token.sol';
import './poly.sol';

contract PermilleCooloffConstraint is Constraint {
  address poly;
  uint256 minLimit;
  uint256 permille;
  // A number of seconds you have to wait between withdrawals.
  uint256 cooloff;
  mapping (address => uint256) lastCooloff;
  mapping (address => uint256) uncooledWithdrawals;

  modifier polyOnly() {
    require(msg.sender == poly);
    _;
  }

  function PermilleCooloffConstraint(
      Poly _poly,
      uint256 _minLimit,
      uint256 _permille,
      uint256 _cooloff)
      public {
    poly = address(_poly);
    minLimit = _minLimit;
    permille = _permille;
    cooloff = _cooloff;
  }

  function allowWithdrawal(
      uint32 _numTotalTiers,
      uint32 _numApprovedTiers,
      Erc20Token _token,
      address /* _recipient */,
      uint256 _amount)
      external
      view
      returns (bool) {
    require(_numTotalTiers == _numApprovedTiers);
    uint256 balance =
        _token == address(0) ? poly.balance : _token.balanceOf(poly);
    uint256 limit = getLimit(balance);

    return _amount <= balance
        && _amount + uncooledWithdrawals[_token] <= limit
        && now > lastCooloff[_token] + cooloff;
  }

  function markWithdrawal(
      Erc20Token _token,
      uint256 _amount)
      polyOnly
      external {
    uncooledWithdrawals[_token] += _amount;
  }

  function startCooloff(
      Erc20Token _token)
      external {
    require(
        uncooledWithdrawals[_token] > 0
        && now > lastCooloff[_token] + cooloff);
    lastCooloff[_token] = now;
    uncooledWithdrawals[_token] = 0;
  }

  function getLimit(
      uint256 balance)
      public
      view
      returns (uint256) {
    return max(permille * balance / 1000, minLimit);
  }

  function max(
      uint256 a,
      uint256 b)
      private
      pure
      returns (uint256) {
    return a > b ? a : b;
  }
}