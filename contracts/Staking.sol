pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// @title NFT Staking 
/// @author Karan J Goraniya
/// @notice You can use this contract for only the most basic simulation
/// @dev All function calls are currently implemented without side effects

contract Staking is ERC721Holder {

    IERC721 public NFTItem;
    using SafeERC20 for IERC20;
    IERC20 private token;
    uint256 private totalTokens;

    uint256 rewardPerBlock = 3;
    uint256 month = 172800;
    uint256 totalStakers;
    uint256 constant deno = 100;

    mapping(address => uint256[]) public stakedTokensByUser;
    mapping(uint256 => int256) public stakedTokensByUserIndexes;

    struct Staker {
        bool staked;
        uint256 block;
    }

    mapping(address => mapping (uint256 => Staker)) public stakes;

    constructor(address _token, address _NFTItem) {
        token = IERC20(_token);
        NFTItem = IERC721(_NFTItem);
    }

    event Stake(address indexed owner, uint256 id, uint256 block);
    event UnStake(address indexed owner, uint256 id, uint256 block, uint256 rewardTokens);


    // @notice It will calculate the rate of the token reward
    // @dev It will block.timestamp to track the time.
    // @return Return the reward rate %


    function calculateRewards(address _user, uint256 _tokenId) public view returns(uint256) {
        uint256 _blocksPassed = block.number - stakes[_user][_tokenId].block;
        
        return _blocksPassed * rewardPerBlock / totalStakers;
    }

    // @notice It will give user to stake the NFT.
    // @dev It will confirm the you have enough NFT to stake.
    // @param It will take Token Id of NFT & Amount.

    function stakeNFT(uint256 _tokenId) public {
        require(NFTItem.ownerOf(_tokenId) == msg.sender, 'you dont own this token');

        stakes[msg.sender][_tokenId] = Staker(true, block.number);
        NFTItem.safeTransferFrom(msg.sender, address(this), _tokenId, "0x00");

        stakedTokensByUser[msg.sender].push(_tokenId);
        stakedTokensByUserIndexes[_tokenId] = int256(stakedTokensByUser[msg.sender].length - 1);

        emit Stake(msg.sender, _tokenId,  block.number);
    }

    // // @notice It will unstake the NFT and distribute the token reward.
    // // @dev It will calculate the reward with calculateRate() and distribute token using IERC20.
    // // @param It will take Token Id of NFT & Amount.
    // // Reward amount = Staked Amount * Reward Rate * TimeDiff / RewardInterval

    function unStakeNFT(uint256 _tokenId) public {
        NFTItem.safeTransferFrom(address(this), msg.sender, _tokenId, "0x00");

        uint256 reward = calculateRewards(msg.sender, _tokenId);

        token.safeTransfer(msg.sender, reward);
        
        stakedTokensByUser[msg.sender][uint256(stakedTokensByUserIndexes[_tokenId])] = stakedTokensByUser[msg.sender][stakedTokensByUser[msg.sender].length - 1];
        stakedTokensByUser[msg.sender].pop();

        stakedTokensByUserIndexes[_tokenId] = -1;

        emit UnStake(msg.sender, _tokenId,  block.number, reward);
    }

}