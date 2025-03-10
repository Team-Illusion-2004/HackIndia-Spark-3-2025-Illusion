// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DeepfakeDetection is ReentrancyGuard {
    IERC20 public testToken;
    uint256 public constant STAKE_AMOUNT = 100 * 10**18; // 100 TEST tokens
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant MIN_VOTES = 5;

    struct Media {
        address uploader;
        string ipfsHash;
        uint256 uploadTime;
        uint256 realVotes;
        uint256 fakeVotes;
        bool isResolved;
        mapping(address => bool) hasVoted;
        mapping(address => bool) votedReal;
    }

    mapping(uint256 => Media) public mediaItems;
    uint256 public mediaCount;

    event MediaUploaded(uint256 indexed mediaId, address indexed uploader, string ipfsHash);
    event VoteCast(uint256 indexed mediaId, address indexed voter, bool votedReal);
    event MediaResolved(uint256 indexed mediaId, bool isReal, address uploader, uint256 reward);

    constructor(address _testToken) {
        testToken = IERC20(_testToken);
    }

    function uploadMedia(string memory _ipfsHash) external nonReentrant {
        require(testToken.balanceOf(msg.sender) >= STAKE_AMOUNT, "Insufficient TEST tokens");
        require(testToken.transferFrom(msg.sender, address(this), STAKE_AMOUNT), "Stake transfer failed");

        uint256 mediaId = mediaCount++;
        Media storage newMedia = mediaItems[mediaId];
        newMedia.uploader = msg.sender;
        newMedia.ipfsHash = _ipfsHash;
        newMedia.uploadTime = block.timestamp;
        newMedia.isResolved = false;

        emit MediaUploaded(mediaId, msg.sender, _ipfsHash);
    }

    function vote(uint256 _mediaId, bool _isReal) external {
        Media storage media = mediaItems[_mediaId];
        require(!media.isResolved, "Media already resolved");
        require(!media.hasVoted[msg.sender], "Already voted");
        require(block.timestamp <= media.uploadTime + VOTING_PERIOD, "Voting period ended");
        require(msg.sender != media.uploader, "Uploader cannot vote");

        media.hasVoted[msg.sender] = true;
        media.votedReal[msg.sender] = _isReal;

        if (_isReal) {
            media.realVotes++;
        } else {
            media.fakeVotes++;
        }

        emit VoteCast(_mediaId, msg.sender, _isReal);

        // Check if we can resolve the media item
        if (media.realVotes + media.fakeVotes >= MIN_VOTES && 
            block.timestamp > media.uploadTime + VOTING_PERIOD) {
            resolveMedia(_mediaId);
        }
    }

    function resolveMedia(uint256 _mediaId) public {
        Media storage media = mediaItems[_mediaId];
        require(!media.isResolved, "Already resolved");
        require(block.timestamp > media.uploadTime + VOTING_PERIOD || 
                media.realVotes + media.fakeVotes >= MIN_VOTES, 
                "Cannot resolve yet");

        media.isResolved = true;
        bool isReal = media.realVotes > media.fakeVotes;
        uint256 reward = STAKE_AMOUNT;

        // If prediction is correct (majority vote matches reality), uploader gets reward
        if (isReal) {
            require(testToken.transfer(media.uploader, reward), "Reward transfer failed");
        }

        emit MediaResolved(_mediaId, isReal, media.uploader, reward);
    }

    function getMediaDetails(uint256 _mediaId) external view returns (
        address uploader,
        string memory ipfsHash,
        uint256 uploadTime,
        uint256 realVotes,
        uint256 fakeVotes,
        bool isResolved
    ) {
        Media storage media = mediaItems[_mediaId];
        return (
            media.uploader,
            media.ipfsHash,
            media.uploadTime,
            media.realVotes,
            media.fakeVotes,
            media.isResolved
        );
    }

    function hasVoted(uint256 _mediaId, address _voter) external view returns (bool) {
        return mediaItems[_mediaId].hasVoted[_voter];
    }
} 