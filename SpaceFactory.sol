// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Space.sol";

contract SpaceFactory {
    event Create(uint256 spaceId, address indexed spaceAddress, uint256 indexed assetId, address creator, string spaceName);
    event FeeUpdated(string feeType, uint256 newFee);
    event AvatarUpdated(address indexed sender, string arTxId, uint256 feePaid);
    event SpaceNameUpdated(address indexed sender, string oldSpaceName, string newSpaceName);

    uint256 public spaceIndex = 0;
    mapping(address => address) public spaces; 
    mapping(uint256 => address) public spaceUsers;
    mapping(address => uint256) public spaceIndexes; 
    mapping(address => string) public spaceNames;
    mapping(address => string) public avatars; 

    address payable public owner; 
    uint256 public updateAvatarFee;  

    constructor() {
        owner = payable(msg.sender); 
        updateAvatarFee = 0.1 ether;  
    }
  
    function setUpdateAvatarFee(uint256 _fee) public onlyOwner {
        updateAvatarFee = _fee;
        emit FeeUpdated("UpdateAvatarFee", _fee);
    }
  
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function withdraw() public onlyOwner {
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    function create(uint256 assetId, string calldata spaceName) public { 
        require(bytes(spaceName).length <= 32, "Space name must be 32 characters or less");
        require(spaces[msg.sender] == address(0), "Space already created");
        Space newSpace = new Space(assetId, msg.sender);
        spaces[msg.sender] = address(newSpace);
        spaceNames[msg.sender] = spaceName;
        spaceIndexes[msg.sender] = spaceIndex;
        spaceUsers[spaceIndex] = msg.sender; 
        emit Create(spaceIndex, address(newSpace), assetId, msg.sender,spaceName);
        spaceIndex++;
    }

    function updateSpaceName(string calldata newSpaceName) public {
        require(bytes(newSpaceName).length <= 32, "Space name must be 32 characters or less");
        require(spaces[msg.sender] != address(0), "Space not created yet");
        string memory oldSpaceName = spaceNames[msg.sender];
        spaceNames[msg.sender] = newSpaceName;
        emit SpaceNameUpdated(msg.sender, oldSpaceName, newSpaceName);
    }

    function uploadAvatar(string calldata arTxId) public payable {
        require(msg.value >= updateAvatarFee, "Insufficient fee");
        avatars[msg.sender] = arTxId;
        (bool success, ) = owner.call{value: msg.value}("");
        require(success, "Transfer failed");
        emit AvatarUpdated(msg.sender, arTxId, msg.value);
    }
   
    function getUserSpaceInfo(address user) public view returns (string memory, string memory, address, uint256) {
        return (spaceNames[user], avatars[user], spaces[user], spaceIndexes[user]);
    }
}
