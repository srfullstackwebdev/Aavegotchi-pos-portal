pragma solidity "0.6.6";

import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import { AccessControl } from "openzeppelin-solidity/contracts/access/AccessControl.sol";
import { IRootChainManager } from "./IRootChainManager.sol";
import { IStateSender } from "./IStateSender.sol";

contract RootChainManager is IRootChainManager, AccessControl {
  bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
  bytes32 public constant MAPPER_ROLE = keccak256("MAPPER_ROLE");

  IStateSender private _stateSender;
  address private _childChainManagerAddress;
  address private _WETHAddress;
  mapping(address => address) private _rootToChildToken;
  mapping(address => address) private _childToRootToken;

  constructor() public {
    _setupRole(OWNER_ROLE, msg.sender);
    _setRoleAdmin(OWNER_ROLE, msg.sender);
    _setupRole(MAPPER_ROLE, msg.sender);
    _setRoleAdmin(MAPPER_ROLE, msg.sender);
  }

  modifier onlyOwner() {
    require(
      hasRole(OWNER_ROLE, msg.sender),
      "Insufficient permissions"
    );
    _;
  }

  modifier onlyMapper() {
    require(
      hasRole(MAPPER_ROLE, msg.sender),
      "Insufficient permissions"
    );
    _;
  }

  function transferOwnerRole(address newOwner) external onlyOwner {
    grantRole(OWNER_ROLE, newOwner);
    grantRole(MAPPER_ROLE, newOwner);

    revokeRole(OWNER_ROLE, msg.sender);
    revokeRole(MAPPER_ROLE, msg.sender);

    _setRoleAdmin(OWNER_ROLE, newOwner);
    _setRoleAdmin(MAPPER_ROLE, newOwner);
  }

  function setStateSender(address newStateSender) override external onlyOwner {
    _stateSender = IStateSender(newStateSender);
  }

  function stateSenderAddress() public view returns (address) {
    return address(_stateSender);
  }

  function setChildChainManagerAddress(address newChildChainManager) external onlyOwner {
    _childChainManagerAddress = newChildChainManager;
  }

  function childChainManagerAddress() public view returns (address) {
    return _childChainManagerAddress;
  }

  function setWETHAddress(address newWETHAddress) external onlyOwner {
    _WETHAddress = newWETHAddress;
  }

  function WETHAddress() public view returns (address) {
    return _WETHAddress;
  }

  function mapToken(address rootToken, address childToken) override external onlyMapper {
    _rootToChildToken[rootToken] = childToken;
    _childToRootToken[childToken] = rootToken;
    emit TokenMapped(rootToken, childToken);
  }

  function rootToChildToken(address rootToken) public view returns (address) {
    return _rootToChildToken[rootToken];
  }

  function childToRootToken(address childToken) public view returns (address) {
    return _childToRootToken[childToken];
  }

  function depositEther() override external payable {
    _depositEtherFor(msg.sender);
  }

  function depositEtherFor(address user) override external payable {
    _depositEtherFor(user);
  }

  function _depositEtherFor(address user) private {
    require(
      _rootToChildToken[_WETHAddress] != address(0x0),
      "WETH not mapped"
    );
    require(
      address(_stateSender) != address(0x0),
      "stateSender not set"
    );
    require(
      address(_childChainManagerAddress) != address(0x0),
      "childChainManager not set"
    );

    _stateSender.syncState(_childChainManagerAddress, abi.encode(user, _WETHAddress, msg.value));
    emit Deposited(user, _WETHAddress, msg.value);
  }

  function deposit(address rootToken, uint256 amount) override external {
    _depositFor(msg.sender, rootToken, amount);
  }

  function depositFor(address user, address rootToken, uint256 amount) override external {
    _depositFor(user, rootToken, amount);
  }

  function _depositFor(address user, address rootToken, uint256 amount) private {
    require(
      _rootToChildToken[rootToken] != address(0x0),
      "Token not mapped"
    );
    require(
      IERC20(rootToken).allowance(msg.sender, address(this)) >= amount,
      "Token transfer not approved"
    );
    require(
      address(_stateSender) != address(0x0),
      "stateSender not set"
    );
    require(
      address(_childChainManagerAddress) != address(0x0),
      "childChainManager not set"
    );

    IERC20(rootToken).transferFrom(msg.sender, address(this), amount);
    _stateSender.syncState(_childChainManagerAddress, abi.encode(user, rootToken, amount));
    emit Deposited(user, rootToken, amount);
  }

  function exit(bytes calldata data) override external {
  
  }
}
