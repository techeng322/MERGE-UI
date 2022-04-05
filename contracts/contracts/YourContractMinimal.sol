//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/*

ASCII ART GOES HERE

*/


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract YourContractMinimal is
    ERC721,
    IERC2981,
    Pausable,
    AccessControl,
    Ownable
{
    using Strings for uint256;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 public constant TEAM_MINT_COUNT = 20;
    uint256 public constant MAX_SUPPLY = 666;
    string public _baseURIextended = "http://localhost:3000/api/metadata/";
    bytes32 public _merkleRoot = 0x7f9947af1470e7df017d480516fb72e1b515240c75cf5afacfd79d475f309f35;
    address payable private _withdrawalWallet;
    address payable private _royaltyWallet;
    uint256 public _royaltyBasis = 750; // 7.5%
    // Sale / Presale
    bool public saleActive = false;
    uint256 public constant ETH_PRICE = 0.069 ether;
    uint256 public constant MAX_MINT_COUNT = 10;

    constructor()
        ERC721("YourContract", "YourContract")
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(MANAGER_ROLE, msg.sender);
    }

    function setWithdrawalWallet(address payable withdrawalWallet_)
        external
        onlyRole(MANAGER_ROLE)
    {
        _withdrawalWallet = (withdrawalWallet_);
    }
    function withdraw()
        external
        onlyRole(MANAGER_ROLE)
    {
        payable(_withdrawalWallet).transfer(address(this).balance);
    }

    function pause()
        public
        onlyRole(MANAGER_ROLE)
    {
        _pause();
    }
    function unpause()
        public
        onlyRole(MANAGER_ROLE)
    {
        _unpause();
    }

    function setBaseURI(string memory baseURI_)
        external
        onlyRole(MANAGER_ROLE)
    {
        _baseURIextended = baseURI_;
    }

    function contractURI()
        external
        view
        returns (string memory)
    {
        return string(abi.encodePacked(_baseURIextended, "metadata.json"));
    }

    function maxSupply()
        external
        pure
        returns (uint256)
    {
        return MAX_SUPPLY;
    }

    function totalSupply()
        external
        view
        returns (uint256)
    {
        return _tokenIds.current();
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(tokenId <= _tokenIds.current(), "Nonexistent token");
        return string(abi.encodePacked(_baseURIextended, tokenId.toString(), ".json"));
    }

    function setSaleActive(bool val)
        external
        onlyRole(MANAGER_ROLE) 
    {
        saleActive = val;
    }

    function transferOwnership(address _newOwner)
        public
        override
        onlyOwner
    {
        address currentOwner = owner();
        revokeRole(MANAGER_ROLE, currentOwner);
        revokeRole(MANAGER_ROLE, currentOwner);
        _transferOwnership(_newOwner);
        grantRole(DEFAULT_ADMIN_ROLE, _newOwner);
        grantRole(MANAGER_ROLE, _newOwner);
    }

    function mint(uint256 count)
        external
        payable
        whenNotPaused
        returns (uint256)
    {
        require(saleActive, "Sale has not begun");
        require((ETH_PRICE * count) == msg.value, "Incorrect ETH sent; check price!");
        require(count <= MAX_MINT_COUNT, "Tried to mint too many NFTs at once");
        require(_tokenIds.current() + count <= MAX_SUPPLY, "SOLD OUT");
        for (uint256 i=0; i<count; i++) {
            _tokenIds.increment();
            _mint(msg.sender, _tokenIds.current());
        }
        return _tokenIds.current();
    }

    // Allows an admin to mint for free, and send it to an address
    // This can be run while the contract is paused
    function teamMint(uint256 count, address recipient)
        external
        onlyRole(MANAGER_ROLE)
    returns (uint256)
    {
        require(_tokenIds.current() + count <= TEAM_MINT_COUNT, "Exceeded maximum");
        require(_tokenIds.current() + count <= MAX_SUPPLY, "SOLD OUT");
        for (uint256 i=0; i<count; i++) {
            _tokenIds.increment();
            _mint(recipient, _tokenIds.current());
        }
        return _tokenIds.current();
    }

    function setRoyaltyWallet(address payable royaltyWallet_)
        external
        onlyRole(MANAGER_ROLE)
    {
        _royaltyWallet = (royaltyWallet_);
    }

    /**
     * @dev See {IERC165-royaltyInfo}.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Nonexistent token");
        return (payable(_royaltyWallet), uint((salePrice * _royaltyBasis)/10000));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, IERC165, AccessControl)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    receive () external payable {}
    fallback () external payable {}
}