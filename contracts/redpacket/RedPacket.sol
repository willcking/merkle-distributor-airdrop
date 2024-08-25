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

    event ClaimSuccess(
        bytes32 id,
        address claimer,
        uint claimed_value,
        address token_address
    );

    event RefundSuccess(
        bytes32 id,
        address token_address,
        uint remaining_balance
    );

    using SafeERC20 for IERC20;
    uint32 nonce;
    bytes32 private seed;
    mapping(bytes32 => RedPackets) redpacket_by_id;

    function initialize() public initializer {
        seed = keccak256(abi.encodePacked(" Redpacket ", block.timestamp, msg.sender));
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

        uint recipient_number = unbox(packed.packed2, 239, 15);
        uint claimed_number = unbox(packed.packed2, 224, 15);
        require (claimed_number < recipient_number, "Out of stock");

        bytes32 merkleroot = redp.merkleRoot;
        require(MerkleProof.verify(proof, merkleroot, _leaf(msg.sender)), 'Verification failed');

        uint256 claimed_tokens;
        uint256 token_type = unbox(packed.packed2, 254, 1);
        uint256 ifrandom = unbox(packed.packed2, 255, 1);
        uint256 remaining_tokens = unbox(packed.packed1, 128, 96);
        address token_address = address(uint160(unbox(packed.packed2, 64, 160)));
        uint minium_value = 10**(IERC20(token_address).decimals() - 1);

        if(ifrandom == 1) {
            if (recipient_number - claimed_number == 1) {
                claimed_tokens = remaining_tokens;
            } else {
                uint reserve_amount = (recipient_number - claimed_number) * minium_value;
                uint distribute_tokens = remaining_tokens - reserve_amount;
                claimed_tokens = random(seed, nonce) % (distribute_tokens * 2/ (recipient_number - claimed_number));
                claimed_tokens = claimed_tokens < minium_value ? minium_value : (claimed_tokens - (claimed_tokens % minium_value));
            }
        } else {
            if (recipient_number - claimed_number == 1) {
                claimed_tokens = remaining_tokens;
            } else {
                claimed_tokens = remaining_tokens/(recipient_number - claimed_number);
            }
        }

        redp.packed.packed1 = rewriteBox(packed.packed1, 128, 96, remaining_tokens - claimed_tokens);

        require(redp.claim_list[msg.sender] == 0, "Already claimed");

        redp.claim_list[msg.sender] = claimed_tokens;
        redp.packed.packed2 = rewriteBox(packed.packed2, 224, 15, claimed_number + 1);

        if (token_type == 0) {
            payable(msg.sender).transfer(claimed_tokens);
        } else if (token_type == 1) {
            transfer_token(token_address, msg.sender, claimed_tokens);
        }
        emit ClaimSuccess(id, msg.sender, claimed_tokens, token_address);
        return claimed_tokens;
    }

    function refund(bytes32 id) public {
        RedPackets storage redp = redpacket_by_id[id];
        Packed memory packed = redp.packed;
        address owner = redp.owner;
        require(owner == msg.sender, "Redpacked Owner Only");
        require(unbox(packed.packed1, 224, 32) <= block.timestamp, "Not expired yet");
        uint256 remaining_tokens = unbox(packed.packed1, 128, 96);
        require(remaining_tokens != 0, "None left in the red packet");

        uint256 token_type = unbox(packed.packed2, 254, 1);
        address token_address = address(uint160(unbox(packed.packed2, 64, 160)));

        redp.packed.packed1 = rewriteBox(packed.packed1, 128, 96, 0);

        if (token_type == 0) {
            payable(msg.sender).transfer(remaining_tokens);
        }
        else if (token_type == 1) {
            transfer_token(token_address, msg.sender, remaining_tokens);
        }

        emit RefundSuccess(id, token_address, remaining_tokens);
    }

    function getRedpacked(bytes32 id) external view returns 
    (
        address token_address,
        uint balance, 
        uint total, 
        uint claimed, 
        bool expired, 
        uint256 claimed_amount
    ) {
        RedPackets storage redp = redpacket_by_id[id];
        Packed memory packed = redp.packed;
        return (
            address(uint160(unbox(packed.packed2, 64, 160))), 
            unbox(packed.packed1, 128, 96), 
            unbox(packed.packed2, 239, 15), 
            unbox(packed.packed2, 224, 15), 
            block.timestamp > unbox(packed.packed1, 224, 32), 
            redp.claim_list[msg.sender]
        );
    }

//-----------------------------Calculation tools-------------------------------------
    function transfer_token(address token_address, address recipient_address, uint amount) internal{
        IERC20(token_address).safeTransfer(recipient_address, amount);
    }

    function random(bytes32 _seed, uint32 nonce_rand) internal view returns (uint rand) {
        return uint(keccak256(abi.encodePacked(nonce_rand, msg.sender, _seed, block.timestamp))) + 1 ;
    }

    function _leaf(address account) internal pure returns (bytes32){
        return keccak256(abi.encodePacked(account));
    }

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

    function rewriteBox (uint256 _box, uint16 position, uint16 size, uint256 data) internal pure returns (uint256 boxed) {
        assembly {
            // mask = ~((1 << size - 1) << position)
            // _box = (mask & _box) | ()data << position)
            boxed := or( and(_box, not(shl(position, sub(shl(size, 1), 1)))), shl(position, data))
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