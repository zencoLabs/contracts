// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {ERC1155TokenReceiver} from "solmate/src/tokens/ERC1155.sol";
import "./IBodhi.sol";

contract Space is ERC1155TokenReceiver {
    event Create(
        uint256 indexed parentId,
        uint256 indexed assetId,
        address indexed sender,
        string arTxId
    );
    event Remove(uint256 indexed assetId, address sender);
    event RemoveBodhi(
        uint256 indexed parentId,
        uint256 indexed assetId,
        address sender
    );
    event BuyBack(
        uint256 indexed spaceAssetId,
        address indexed sender,
        uint256 tokenAmount,
        uint256 ethAmount
    );

    IBodhi public constant bodhi =
        IBodhi(0x8920b2B8C488546B30106067894402992f9D09D7);
    uint256 public immutable spaceAssetId;
    address public immutable owner;

    constructor(uint256 _assetId, address _owner) {
        (, , address creator) = bodhi.assets(_assetId);
        require(_owner == creator, "Only creator can create its Space");
        spaceAssetId = _assetId;
        owner = _owner;
    }

    mapping(uint256 => uint256) public assetToParent;
    mapping(uint256 => address) public assetToCreator;
    mapping(uint256 => uint256[]) public parentToAssets; // Mapping to store parentId and its associated assetIds

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    function create(string calldata arTxId, uint256 parentId) external {
        // require(parentId == 0 || assetToParent[parentId] != 0, "Parent not exists");
        uint256 assetId = bodhi.assetIndex();
        // uint256 _parentId = parentId != 0 ? parentId : assetId;
        assetToParent[assetId] = parentId;
        assetToCreator[assetId] = msg.sender;

        parentToAssets[parentId].push(assetId); // Add assetId to parentId's list

        bodhi.create(arTxId); // Ensure state changes before emitting events
        emit Create(parentId, assetId, msg.sender, arTxId);

        require(
            bodhi.balanceOf(address(this), assetId) >= 1 ether,
            "Insufficient asset balance"
        );
        bodhi.safeTransferFrom(address(this), msg.sender, assetId, 1 ether, "");
    }

    function removeFromSpace(uint256[] calldata assetIds) external {
        require(msg.sender == owner, "Only owner can remove");
        for (uint256 i = 0; i < assetIds.length; i++) {
            uint256 parentId = assetToParent[assetIds[i]];
            _removeAssetFromParent(parentId, assetIds[i]);

            delete assetToParent[assetIds[i]];
            emit Remove(assetIds[i], msg.sender);
        }
    }

    function _removeAssetFromParent(uint256 parentId, uint256 assetId)
        internal
    {
        uint256[] storage assets = parentToAssets[parentId];
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == assetId) {
                assets[i] = assets[assets.length - 1];
                assets.pop();
                break;
            }
        }
    }

    function removeFromBodhi(uint256 parentId, uint256 assetId) external {
        require(
            assetToCreator[assetId] == msg.sender,
            "Only creator can remove"
        );
        bodhi.remove(assetId);
        emit RemoveBodhi(parentId, assetId, msg.sender);
    }

    function removeFromBodhiByOwner(uint256 parentId, uint256[] memory assetIds)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < assetIds.length; i++) {
            uint256 assetId = assetIds[i];
            bodhi.remove(assetId);
            emit RemoveBodhi(parentId, assetId, msg.sender);
        }
    }

    function buyback(uint256 amount) external payable {
        require(msg.sender == owner, "Only owner can buyback");
        require(amount > 0, "Amount must be greater than zero");
        uint256 price = bodhi.getBuyPriceAfterFee(spaceAssetId, amount);
        require(msg.value >= price, "Insufficient payment");
        emit BuyBack(spaceAssetId, msg.sender, amount, price);
        bodhi.buy{value: price}(spaceAssetId, amount);
        if (msg.value > price) {
            (bool refunded, ) = payable(msg.sender).call{
                value: msg.value - price
            }("");
            require(refunded, "Failed to refund excess payment");
        }
    }

    function getAssetsByParent(uint256 parentId)
        external
        view
        returns (uint256[] memory)
    {
        return parentToAssets[parentId];
    }

    receive() external payable {}
}
