//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './interface/IERC721SR.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract ERC721SR is IERC721SR, ERC721 {
  using SafeERC20 for IERC20;

  // One epoch one day
  uint256 public constant EpochLength = 86400;
  //
  uint256 public currentEpoch;
  //
  uint256 public lastEpochTime;

  // counted token address
  IERC20[] public tokenLists;

  // epoch => token => token reward
  mapping(uint256 => mapping(IERC20 => uint256)) public epochReward;

  // token => epoch => reward
  mapping(IERC20 => mapping(uint256 => uint256)) public balanceByEpoch;

  // token last claim epoch
  // tokenId => epoch
  mapping(uint256 => uint256) public tokenIdLastClaimEpoch;

  mapping(IERC20 => uint256) rewardClaimedTmp;

  uint256 totalHolderCount;

  constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
    lastEpochTime = block.timestamp;
  }

  function addToken(IERC20 token) external {
    tokenLists.push(token);
  }

  /**
   * @dev
   */
  function checkEpoch() external {
    _checkEpoch();
  }

  function _checkEpoch() internal {
    uint256 epochBefore = currentEpoch;
    if (block.timestamp - lastEpochTime > EpochLength) {
      uint256 n = (block.timestamp - lastEpochTime) / EpochLength;
      currentEpoch += n;
      lastEpochTime = block.timestamp + n * EpochLength;

      for (uint256 i = 0; i < tokenLists.length; i++) {
        IERC20 token = tokenLists[i];
        uint256 currentBalance = IERC20(token).balanceOf(address(this));
        uint256 newRoyalty = currentBalance - balanceByEpoch[token][epochBefore] - rewardClaimedTmp[token];
        epochReward[currentEpoch][token] += newRoyalty;
        rewardClaimedTmp[token] = 0;
        balanceByEpoch[token][currentEpoch] = currentBalance;
      }
    }
  }

  function claim(uint256 tokenId, IERC20 token) external {
    require(ownerOf(tokenId) == msg.sender, 'ERC721SR: not token owner');
    _checkEpoch();

    uint256 totalReward = 0;
    for (uint256 i = 0; i < currentEpoch - tokenIdLastClaimEpoch[tokenId]; i++) {
      totalReward += epochReward[tokenIdLastClaimEpoch[tokenId] + i][token] / totalHolderCount;
    }

    tokenIdLastClaimEpoch[tokenId] = currentEpoch;

    IERC20(token).safeTransferFrom(address(this), msg.sender, totalReward);
  }

  /**
   * @dev I'm considering whether it is necessary
   */
  function _afterTokenTransfer(
    address,
    address,
    uint256
  ) internal virtual override {
    _checkEpoch();
  }
}
