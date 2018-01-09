pragma solidity ^0.4.19;

import './proposal.sol';

contract Tier {
  // After configuring the contract, the admin should lock it, which prevents
  // futher configuration even if the admin address is leaked.
  bool public locked = false;

  address admin;

  mapping (address => bool) authorities;
  uint32 numAuthorities = 0;
  // The first address is a proposal, the second is a signing authority.
  mapping (address => mapping (address => bool)) signingAuthorities;
  mapping (address => uint32) numSigningAuthorities;
  // Once a proposal is vetoed it cannot be unvetoed, but a new proposal could
  // be created.
  mapping (address => mapping (address => bool)) vetoingAuthorities;
  mapping (address => uint32) numVetoingAuthorities;
  uint32 requiredSigningAuthorities = 0;
  uint256 public delay = 0;

  modifier unlockedOnly() {
    require(!locked);
    _;
  }

  modifier lockedOnly() {
    require(locked);
    _;
  }

  modifier adminOnly() {
    require(msg.sender == admin);
    _;
  }

  modifier authorityOnly() {
    require(authorities[msg.sender]);
    _;
  }

  function Tier() public {
    admin = msg.sender;
  }

  function lock()
      unlockedOnly
      adminOnly
      external {
    require(
        requiredSigningAuthorities > 0
        && requiredSigningAuthorities <= numAuthorities);
    locked = true;
  }

  function addAuthority(
      address _authority)
      unlockedOnly
      adminOnly
      external {
    require(!authorities[_authority]);
    authorities[_authority] = true;
    numAuthorities++;
  }

  function setRequiredSigningAuthorities(
      uint32 _num)
      unlockedOnly
      adminOnly
      external {
    requiredSigningAuthorities = _num;
  }

  function setWithdrawalDelay(
      uint256 _delay)
      unlockedOnly
      adminOnly
      external {
    delay = _delay;
  }

  function sign(
      Proposal _proposal)
      lockedOnly
      authorityOnly
      external {
    require(!signingAuthorities[_proposal][msg.sender]);
    signingAuthorities[_proposal][msg.sender] = true;
    numSigningAuthorities[_proposal]++;
  }

  function veto(
      Proposal _proposal)
      lockedOnly
      authorityOnly
      external {
    require(!vetoingAuthorities[_proposal][msg.sender]);
    vetoingAuthorities[_proposal][msg.sender] = true;
    numVetoingAuthorities[_proposal]++;
  }

  function isApproved(
      Proposal _proposal)
      lockedOnly
      external
      view
      returns (bool) {
    uint32 signCount = numSigningAuthorities[_proposal];
    return signCount >= requiredSigningAuthorities
        && signCount > numVetoingAuthorities[_proposal];
  }

  function isVetoed(
      Proposal _proposal)
      lockedOnly
      external
      view
      returns (bool) {
    // If there are an equal number of vetoers as approvers, then veto wins the
    // tie.
    uint32 vetoCount = numVetoingAuthorities[_proposal];
    return vetoCount >= requiredSigningAuthorities
        && vetoCount >= numSigningAuthorities[_proposal];
  }
}
