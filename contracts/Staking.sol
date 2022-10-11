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

    mapping(address => uint256[]) private stakedTokensByUser;
    mapping(uint256 => int256) public stakedTokensByUserIndexes;

    struct Staker {
        bool staked;
        uint256 block;
        uint256 harvested;
    }

    mapping(address => mapping (uint256 => Staker)) public stakes;

    constructor(address _token, address _NFTItem) {
        token = IERC20(_token);
        NFTItem = IERC721(_NFTItem);
    }

    event Stake(address indexed owner, uint256 id, uint256 block);
    event UnStake(address indexed owner, uint256 id, uint256 block, uint256 rewardTokens);


    function getStakedTokenIdsByUser(address _user) public view returns(uint256[] memory) {
        return stakedTokensByUser[_user];
    }

    // @notice It will calculate the rate of the token reward
    // @dev It will block.timestamp to track the time.
    // @return Return the reward rate %

    
    function calculateRewards(address _user, uint256 _tokenId) public view returns(uint256) {
        uint256 _blocksPassed = block.number - stakes[_user][_tokenId].block;
        
        return totalStakers == 0 ? 0 : _blocksPassed * rewardPerBlock * 10**18 / totalStakers - stakes[_user][_tokenId].harvested;
    }

    function stakeNFTs(uint256[] memory _tokenIds) external {
        require(_tokenIds.length <= 100, "Staking: Maximum amount of token ids exceeded");
        
        for(uint i; i < _tokenIds.length; i++) {
             stakeNFT(_tokenIds[i]);
        }
    }

    // @notice It will give user to stake the NFT.
    // @dev It will confirm the you have enough NFT to stake.
    // @param It will take Token Id of NFT & Amount.

    function stakeNFT(uint256 _tokenId) public {
        require(NFTItem.ownerOf(_tokenId) == msg.sender, 'you dont own this token');

        stakes[msg.sender][_tokenId] = Staker(true, block.number, 0);
        NFTItem.safeTransferFrom(msg.sender, address(this), _tokenId, "0x00");

        stakedTokensByUser[msg.sender].push(_tokenId);
        stakedTokensByUserIndexes[_tokenId] = int256(stakedTokensByUser[msg.sender].length - 1);

        totalStakers++;

        emit Stake(msg.sender, _tokenId,  block.number);
    }

    function unStakeNFTs(uint256[] memory _tokenIds) external {
        require(_tokenIds.length <= 100, "Staking: Maximum amount of token ids exceeded");

        for(uint i; i < _tokenIds.length; i++) {
             unStakeNFT(_tokenIds[i]);
        }
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

        totalStakers--;

        emit UnStake(msg.sender, _tokenId,  block.number, reward);
    }

    function harvestBatch(uint256[] memory _tokenIds) public {
        require(_tokenIds.length <= 100, "Staking: Maximum amount of token ids exceeded");
        uint rewards;
        uint rewardPerToken;

        for(uint i; i < _tokenIds.length; i++) {
            require(stakes[msg.sender][_tokenIds[i]].staked, "Staking: No stake with this token id");
            
            rewardPerToken = calculateRewards(msg.sender, _tokenIds[i]);
            rewards += rewardPerToken;

            stakes[msg.sender][_tokenIds[i]].harvested += rewardPerToken;
        }

        token.safeTransfer(msg.sender, rewards);
    }

    function harvest(uint256 _tokenId) public {
        require(stakes[msg.sender][_tokenId].staked, "Staking: No stake with this token id");
        uint256 reward = calculateRewards(msg.sender, _tokenId);
        stakes[msg.sender][_tokenId].harvested += reward;

        token.safeTransfer(msg.sender, reward);
    }
    

}