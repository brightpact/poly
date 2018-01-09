/**
 * Poly is a tiered multisig contract designed to store ether and ERC-20 tokens.
 * The tiers allow one to have separation between different security levels or
 * authority levels of signers. For example, participants may keep separate
 * cold and hot wallets in different tiers, allowing small withdrawals with only
 * one tier of approval but requiring both wallet signatures for larger
 * withdrawals.
 */

pragma solidity ^0.4.19;

import './constraint.sol';
import './erc20_token.sol';
import './proposal.sol';
import './tier.sol';

// TODO: Allow cancelling support for a proposal.
// TODO: Allow vetoing a proposal that's supported by others?
contract Poly {

  address admin;
  // After configuring the contract, the admin should lock it, which prevents
  // futher configuration even if the admin address is leaked.
  bool locked = false;
  Tier[] tiers;
  mapping (address => uint32) tierIndices;
  Constraint constraint;
  // Map from Proposal address to number of tiers which have approved it.
  // Tiers *must* be approved *in order*. So a `1` indicates that only tier 0
  // has approved it, and a `3` indicates that tiers 0-2 have approved it.
  mapping (address => uint32) public numApprovedTiers;
  // A tier can veto a proposal at its own tier or of a lesser tier
  // (`vetoLevel >= numApprovedTiers`). A tier cannot veto a proposal which has
  // been approved by a higher tier (`numApprovedTiers > vetoLevel`). This means
  // the top tier can veto all proposals.
  mapping (address => uint32) public vetoLevel;
  mapping (address => uint256) public delayStart;
  mapping (address => bool) closedProposals;

  event Deposit(
      address indexed from,
      uint256 value);
  event Withdraw(
      Erc20Token indexed token,
      address indexed to,
      uint256 value);

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

  // TODO: Should constructors have modifiers, like `public`?
  function Poly() public {
    admin = msg.sender;
  }

  // Allow payments to this contract.
  // TODO: In examples it seems more common for this to be `public payable`.
  // Why?
  function() external payable {
    Deposit(msg.sender, msg.value);
  }

  function lock()
      unlockedOnly
      adminOnly
      external {
    require(constraint != address(0));
    // We know the tiers are already locked because we require them to be locked
    // when they're added.
    locked = true;
  }

  // It's best to order tiers from least authority to most authority. Later
  // tiers can veto proposals made by earlier tiers and when approved tiers are
  // counted, the count always starts with the first tier, indicating only a low
  // level of support.
  function addTier(
      Tier _tier)
      unlockedOnly
      adminOnly
      external {
    require(_tier.locked());
    tiers.push(_tier);
    require(tiers.length + 1 == uint32(tiers.length + 1));
    tierIndices[_tier] = uint32(tiers.length) - 1;
  }

  function setConstraint(
      Constraint _constraint)
      unlockedOnly
      adminOnly
      external {
    constraint = _constraint;
  }

  // Returns a number indicating the status of the approval:
  // - 0 approval failed (unused).
  // - 1 approval successful, others still needed.
  // - 2 no more approvals needed.
  function updateNextTierApproval(
      Proposal _proposal)
      lockedOnly
      external
      returns (uint8 status) {
    uint32 nextTier = numApprovedTiers[_proposal];
    if (nextTier == tiers.length) {
      // No more approvals needed.
      return 2;
    }
    require(tiers[nextTier].isApproved(_proposal));
    nextTier++;
    numApprovedTiers[_proposal] = nextTier;
    if (nextTier == tiers.length) {
      // No more approvals needed.
      return 2;
    }
    // Successful, but more approvals are still needed.
    return 1;
  }

  function unapproveTier(
      Proposal _proposal,
      Tier _tier)
      lockedOnly
      external {
    require(!_tier.isApproved(_proposal));
    uint32 level = tierIndices[_tier];
    numApprovedTiers[_proposal] = level;
  }

  function updateVetoLevel(
      Proposal _proposal,
      Tier _tier)
      lockedOnly
      external {
    require(_tier.isVetoed(_proposal));
    uint32 level = tierIndices[_tier];
    if (vetoLevel[_proposal] <= level) {
      vetoLevel[_proposal] = level + 1;
    }
  }

  function unvetoTier(
      Proposal _proposal,
      Tier _tier)
      lockedOnly
      external {
    require(!_tier.isVetoed(_proposal));
    vetoLevel[_proposal] = 0;
  }

  // This doesn't need to be called if the highest approved tier doesn't require
  // a delay.
  function startWithdrawalDelay(
      Proposal _proposal)
      lockedOnly
      external {
    require(passesApprovals(_proposal));
    require(delayStart[_proposal] == 0);
    delayStart[_proposal] = now;
  }

  // If a proposal is vetoed, the delay start can be reset so that any further
  // approval requires another delay before withdrawal.
  function resetWithdrawalDelay(
      Proposal _proposal)
      lockedOnly
      external {
    require(vetoLevel[_proposal] >= numApprovedTiers[_proposal]);
    delayStart[_proposal] = 0;
  }

  function withdraw(
      Proposal _proposal)
      lockedOnly
      external {
    require(!closedProposals[_proposal]);
    closedProposals[_proposal] = true;

    require(passesApprovals(_proposal));

    // If a delay is required by the tier, we must ensure it has been upheld.
    uint32 numApproved = numApprovedTiers[_proposal];
    uint256 requiredDelay = tiers[numApproved - 1].delay();
    uint256 start = delayStart[_proposal];
    require(requiredDelay == 0 || start != 0 && requiredDelay < now - start);

    Erc20Token token = _proposal.token();
    address recipient = _proposal.recipient();
    uint256 amount = _proposal.amount();
    constraint.markWithdrawal(
        numApproved,
        token,
        amount);
    // If `token` is `0x0`, then withdraw ether.
    if (token == address(0)) {
      recipient.transfer(amount);
    } else {
      token.transfer(recipient, amount);
    }
    Withdraw(token, recipient, amount);
  }

  function passesApprovals(
      Proposal _proposal)
      lockedOnly
      view
      private
      returns (bool) {
    uint32 numApproved = numApprovedTiers[_proposal];
    if (numApproved <= vetoLevel[_proposal]) {
      return false;
    }

    Erc20Token token = _proposal.token();
    address recipient = _proposal.recipient();
    uint256 amount = _proposal.amount();
    return constraint.allowWithdrawal(
        uint32(tiers.length),
        numApproved,
        token,
        recipient,
        amount);
  }
}
