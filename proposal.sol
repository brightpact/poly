pragma solidity ^0.4.19;

import './erc20_token.sol';

contract Proposal {
  Erc20Token public token;
  uint256 public amount;
  address public recipient;

  // Set `_token` to 0x0 to indicate ether rather than an ERC20 token.
  function Proposal(
      Erc20Token _token,
      uint256 _amount,
      address _recipient)
      public {
    token = _token;
    amount = _amount;
    recipient = _recipient;
  }
}