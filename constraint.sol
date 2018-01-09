pragma solidity ^0.4.19;

import './erc20_token.sol';

contract Constraint {
  function allowWithdrawal(
      uint32 _numTotalTiers,
      uint32 _numApprovedTiers,
      Erc20Token _token,
      address _recipient,
      uint256 _amount)
      external
      view
      returns (bool allowed);

  function markWithdrawal(
      uint32 _numApprovedTiers,
      Erc20Token _token,
      uint256 _amount)
      external
      returns (bool success);
}