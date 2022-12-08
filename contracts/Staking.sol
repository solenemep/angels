//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Registry.sol";
import "./Scion.sol";

/// @title NFT Staking
/// @dev written with the help of https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol

contract Staking is OwnableUpgradeable, ERC721Holder, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;

    IERC20 public keter;
    Scion public scion;

    uint256 public rewardPerBlock;
    uint256 public totalNFTStaked;
    uint256 public lastBlockUpdate;
    uint256 public rewardPerTokenStored;

    struct Stake {
        EnumerableSet.UintSet stakedTokenIds;
        uint256 userRewardPerTokenPaid;
        uint256 rewards;
    }

    mapping(address => Stake) internal _stakes;

    event StakeNFT(address indexed owner, uint256 id, uint256 block);
    event UnStakeNFT(address indexed owner, uint256 id, uint256 block);

    function __Staking_init() external initializer updateReward(address(0)) {
        rewardPerBlock = 3;

        __Ownable_init();
        __ReentrancyGuard_init();
    }

    function setDependencies(address registryAddress) external onlyOwner {
        keter = IERC20(Registry(registryAddress).getContract("KETER"));
        scion = Scion(Registry(registryAddress).getContract("SCION"));
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        lastBlockUpdate = block.number;

        if (_account != address(0)) {
            _stakes[_account].rewards = earned(_account);
            _stakes[_account].userRewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalNFTStaked == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                (block.number.sub(lastBlockUpdate)).mul(rewardPerBlock).mul(1e18).div(
                    totalNFTStaked
                )
            );
    }

    function earned(address _account) public view returns (uint256) {
        return
            _stakes[_account]
                .stakedTokenIds
                .length()
                .mul(rewardPerToken().sub(_stakes[_account].userRewardPerTokenPaid))
                .add(_stakes[_account].rewards);
    }

    function stakeNFTs(uint256[] memory _tokenIds) external {
        require(_tokenIds.length <= 100, "Staking: Maximum amount of token ids exceeded");

        for (uint256 i; i < _tokenIds.length; i++) {
            _stakeNFT(_tokenIds[i]);
        }
    }

    function stakeNFT(uint256 _tokenId) external {
        _stakeNFT(_tokenId);
    }

    function _stakeNFT(uint256 _tokenId) internal nonReentrant updateReward(_msgSender()) {
        require(scion.ownerOf(_tokenId) == _msgSender(), "you dont own this token");

        _stakes[_msgSender()].stakedTokenIds.add(_tokenId);
        scion.safeTransferFrom(_msgSender(), address(this), _tokenId, "0x00");

        totalNFTStaked++;

        emit StakeNFT(_msgSender(), _tokenId, block.number);
    }

    function unStakeNFTs(uint256[] memory _tokenIds) external {
        require(_tokenIds.length <= 100, "Staking: Maximum amount of token ids exceeded");

        for (uint256 i; i < _tokenIds.length; i++) {
            _unStakeNFT(_tokenIds[i]);
        }
    }

    function unStakeNFT(uint256 _tokenId) external {
        _unStakeNFT(_tokenId);
    }

    function _unStakeNFT(uint256 _tokenId) internal nonReentrant updateReward(_msgSender()) {
        require(
            _stakes[_msgSender()].stakedTokenIds.contains(_tokenId),
            "Staking: No stake with this token id"
        );

        _stakes[_msgSender()].stakedTokenIds.remove(_tokenId);
        scion.safeTransferFrom(address(this), _msgSender(), _tokenId, "0x00");

        totalNFTStaked--;

        emit UnStakeNFT(_msgSender(), _tokenId, block.number);
    }

    function getReward() external nonReentrant updateReward(_msgSender()) {
        uint256 reward = _stakes[_msgSender()].rewards;
        if (reward > 0) {
            _stakes[_msgSender()].rewards = 0;
            keter.transfer(_msgSender(), reward);
        }
    }

    function getStakedTokenIdsByUser(address _account)
        public
        view
        returns (uint256[] memory stakedTokensByUser)
    {
        uint256 count = _stakes[_account].stakedTokenIds.length();
        stakedTokensByUser = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = _stakes[_account].stakedTokenIds.at(i);
            stakedTokensByUser[i] = tokenId;
        }
    }

    function userRewardPerTokenPaid(address _account) public view returns (uint256) {
        return _stakes[_account].userRewardPerTokenPaid;
    }

    function rewards(address _account) public view returns (uint256) {
        return _stakes[_account].rewards;
    }
}
