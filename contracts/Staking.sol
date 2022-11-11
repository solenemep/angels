pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title NFT Staking
/// @dev written with the help of https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol

contract Staking is ERC721Holder, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public keter;
    IERC721 public nft;

    uint256 public rewardPerBlock = 3;
    uint256 public totalNFTStaked;
    uint256 public lastBlockUpdate;
    uint256 public rewardPerTokenStored;

    struct Stake {
        EnumerableSet.UintSet stakedTokenIds;
        uint256 userRewardPerTokenPaid;
        uint256 rewards;
    }

    mapping(address => Stake) internal _stakes;

    constructor(address keterAddress, address NFTAddress) updateReward(address(0)) {
        keter = IERC20(keterAddress);
        nft = IERC721(NFTAddress);
    }

    event StakeNFT(address indexed owner, uint256 id, uint256 block);
    event UnStakeNFT(address indexed owner, uint256 id, uint256 block);

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
                .div(1e18)
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

    function _stakeNFT(uint256 _tokenId) internal nonReentrant updateReward(msg.sender) {
        require(nft.ownerOf(_tokenId) == msg.sender, "you dont own this token");

        _stakes[msg.sender].stakedTokenIds.add(_tokenId);
        nft.safeTransferFrom(msg.sender, address(this), _tokenId, "0x00");

        totalNFTStaked++;

        emit StakeNFT(msg.sender, _tokenId, block.number);
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

    function _unStakeNFT(uint256 _tokenId) internal nonReentrant updateReward(msg.sender) {
        require(
            _stakes[msg.sender].stakedTokenIds.contains(_tokenId),
            "Staking: No stake with this token id"
        );

        _stakes[msg.sender].stakedTokenIds.remove(_tokenId);
        nft.safeTransferFrom(address(this), msg.sender, _tokenId, "0x00");

        totalNFTStaked--;

        emit UnStakeNFT(msg.sender, _tokenId, block.number);
    }

    function getReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = _stakes[msg.sender].rewards;
        if (reward > 0) {
            _stakes[msg.sender].rewards = 0;
            keter.safeTransfer(msg.sender, reward);
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
