// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "../lib/IERC20.sol";
import "../lib/SafeERC20.sol";
import "../lib/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract RedPacket is Initializable {
    struct RedPackets {
        Packed packed;
        mapping(address => uint256) claim_list;
        bytes32 merkleRoot;
        address owner;
    }

    struct Packed {
        uint256 packed1;  // 0 (128) total_tokens (96) expire_time(32)
        uint256 packed2;  // 0 (64) token_addr (160) claimed_numbers(15) recipient_numbers(15) token_type(1) ifrandom(1)
    }

    event CreationSuccess(
        uint total,
        bytes32 id,
        string name,
        string message,
        address creator,
        uint creation_time,
        address token_address,
        uint number,
        bool ifrandom,
        uint duration
    );

    using SafeERC20 for IERC20;
    uint32 nonce;
    bytes32 private seed;
    mapping(bytes32 => RedPackets) redpacket_by_id;

    constructor() public initializer {
        seed = keccak256(abi.encodePacked("RedPacket", block.timestamp, msg.sender));
    }

    function create_redPacked
    (
        bytes32 _merkleroot,
        uint recipient_number, 
        bool _ifrandom, 
        uint _duration, 
        bytes32 _seed, 
        string memory _message, 
        string memory _name,
        uint _token_type, 
        address _token_addr, 
        uint _total_tokens
    ) 
    public payable {
        nonce++;

        require(_total_tokens >= recipient_number, "tokens > recipient_number");
        require(recipient_number > 0, "At least 1 recipient");
        require(recipient_number < 256, "At most 255 recipients");
        require(_token_type == 0 || _token_type == 1, "Unrecognizable token type");
        // require minimum 0.1 for each user
        require(_total_tokens > 10**(IERC20(_token_addr).decimals() - 1) * recipient_number, "At least 0.1 for each user");

        uint256 received_amount = 0;

        if (_token_type == 0) {
            require(msg.value >= _total_tokens, "No enough ETH");
        } else if (_token_type == 1) {
            uint256 balance_before_transfer = IERC20(_token_addr).balanceOf(address(this));
            IERC20(_token_addr).safeTransferFrom(msg.sender, address(this), _total_tokens);
            uint256 balance_after_transfer = IERC20(_token_addr).balanceOf(address(this));
            received_amount = balance_after_transfer - balance_before_transfer;
            require(received_amount >= _total_tokens, "No enough ETH");
        }

        bytes32 _id = keccak256(abi.encodePacked(msg.sender, block.timestamp, nonce, seed, _seed));
        {
            uint _random_type = _ifrandom ? 1 : 0;
            RedPackets storage redp = redpacket_by_id[_id];
            redp.packed.packed1 = wrap1(received_amount, _duration);
            redp.packed.packed2 = wrap2(_token_addr, recipient_number, _token_type, _random_type);
            redp.merkleRoot = _merkleroot;
            redp.owner = msg.sender;
        }
        {
            // as a workaround for "CompilerError: Stack too deep, try removing local variables"
            uint number = recipient_number;
            bool ifrandom = _ifrandom;
            uint duration = _duration;
            emit CreationSuccess(received_amount, _id, _name, _message, msg.sender, block.timestamp, _token_addr, number, ifrandom, duration);
        }
    }

    function claim(bytes32 id, bytes32[] memory proof) public returns(uint claimed) {
        RedPackets storage redp = redpacket_by_id[id];
        Packed memory packed = redp.packed;

        require(unbox(packed.packed1, 224, 32) > block.timestamp, "Expired");


    }

//-----------------------------Calculation tools-------------------------------------
    function box (uint16 position, uint16 size, uint256 data) internal pure returns (uint256 boxed) {
        require(validRange(size, data), "Value out of range BOX");
        assembly {
            // data << position
            boxed := shl(position, data)
        }
    }

    function unbox (uint256 base, uint16 position, uint16 size) internal pure returns (uint256 unboxed) {
        require(validRange(256, base), "Value out of range UNBOX");
        assembly {
            // (((1 << size) - 1) & base >> position)
            unboxed := and(sub(shl(size, 1), 1), shr(position, base))
        }
    }

    function validRange (uint16 size, uint256 data) internal pure returns(bool ifValid) { 
        assembly {
            // 2^size > data or size ==256
            ifValid := or(eq(size, 256), gt(shl(size, 1), data))
        }
    }

    function wrap1 (uint _total_tokens, uint _duration) internal view returns (uint256 packed1) {
        uint256 _packed1 = 0;
        _packed1 |= box(128, 96, _total_tokens);     
        _packed1 |= box(224, 32, (block.timestamp + _duration));    
        return _packed1;
    }

    function wrap2 (address _token_addr, uint _number, uint _token_type, uint _ifrandom) internal pure returns (uint256 packed2) {
        uint256 _packed2 = 0;
        _packed2 |= box(64, 160, uint160(_token_addr));   
        _packed2 |= box(224, 15, 0);                   
        _packed2 |= box(239, 15, _number);              
        _packed2 |= box(254, 1, _token_type);             
        _packed2 |= box(255, 1, _ifrandom);                 
        return _packed2;
    }
}