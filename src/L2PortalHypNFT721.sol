// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "@hyperlane/contracts/token/HypERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
* @author L2Portal
* @title NogemHyper
*/
contract NogemHyper is HypERC721, ReentrancyGuard {
    /************
    *   ERRORS  *
    ************/

    /**
    * @notice Contract error codes, used to specify the error
    * CODE LIST:
    * E1    "Invalid token URI lock state"
    * E2    "Mint exceeds the limit"
    * E3    "Invalid mint fee"
    * E4    "Invalid token ID"
    * E5    "Invalid fee collector address"
    * E6    "Invalid earned fee amount: nothing to claim"
    * E7    "Caller is not a fee collector"
    * E8    "Invalid referral bips: value is too high"
    * E9    "Invalid referer address"
    */
    uint8 public constant ERROR_INVALID_URI_LOCK_STATE = 1;
    uint8 public constant ERROR_MINT_EXCEEDS_LIMIT = 2;
    uint8 public constant ERROR_MINT_INVALID_FEE = 3;
    uint8 public constant ERROR_INVALID_TOKEN_ID = 4;
    uint8 public constant ERROR_INVALID_COLLECTOR_ADDRESS = 5;
    uint8 public constant ERROR_NOTHING_TO_CLAIM = 6;
    uint8 public constant ERROR_NOT_FEE_COLLECTOR = 7;
    uint8 public constant ERROR_REFERRAL_BIPS_TOO_HIGH = 8;
    uint8 public constant ERROR_INVALID_REFERER = 9;

    /**
    * @notice Basic error, thrown every time something goes wrong according to the contract logic.
    * @dev The error code indicates more details.
    */
    error L2PortalHypNFT721_CoreError(uint256 errorCode);

    /************
    *   EVENTS  *
    ************/

    /**
    * State change
    */
    event MintFeeChanged(uint256 indexed oldMintFee, uint256 indexed newMintFee);
    event BridgeFeeChanged(uint256 indexed oldBridgeFee, uint256 indexed newBridgeFee);
    event ReferralEarningBipsChanged(uint256 indexed oldReferralEarningBips, uint256 indexed newReferralEarningBips);
    event EarningBipsForReferrerChanged(address indexed referrer, uint256 newEraningBips);
    event EarningBipsForReferrersChanged(address[] indexed referrers, uint256 newEraningBips);
    event FeeCollectorChanged(address indexed oldFeeCollector, address indexed newFeeCollector);
    event TokenURIChanged(string indexed oldTokenURI, string indexed newTokenURI);
    event TokenURILocked(bool indexed newState);

    /**
    * Mint / bridge / claim
    */
    event ONFTMinted(
        address indexed minter,
        uint256 indexed itemId,
        uint256 feeEarnings,
        address indexed referrer,
        uint256 referrerEarnings
    );

    event BridgeFeeEarned(
        bytes32 indexed to,
        uint32 indexed domain,
        uint256 amount
    );

    event FeeEarningsClaimed(address indexed collector, uint256 claimedAmount);
    event ReferrerEarningsClaimed(address indexed referrer, uint256 claimedAmount);

    /***************
    *   CONSTANTS  *
    ***************/
    uint256 public constant ONE_HUNDRED_PERCENT = 10000; // 100%
    uint256 public constant FIFTY_PERCENT = 5000; // 50%
    uint256 public constant DENOMINATOR = ONE_HUNDRED_PERCENT; // 100%

    /***********************
    *   VARIABLES / STATES *
    ***********************/

    /// TOKEN ID ///
    uint256 public immutable startMintId;
    uint256 public immutable maxMintId;

    uint256 public tokenCounter;

    /// FEE ///
    uint256 public mintFee;
    uint256 public bridgeFee;
    address public feeCollector;

    uint256 public feeEarnedAmount;
    uint256 public feeClaimedAmount;

    /// REFERRAL FEE ///
    uint256 public referralEarningBips;
    mapping (address => uint256) public referrersEarningBips;
    mapping (address => uint256) public referredTransactionsCount;
    mapping (address => uint256) public referrersEarnedAmount;
    mapping (address => uint256) public referrersClaimedAmount;

    /// TOKEN URI ///
    string private _tokenBaseURI;
    bool public tokenBaseURILocked;

    /***************
    *   MODIFIERS  *
    ***************/

    /**
    * @dev Protects functions available only to the fee collector, e.g. fee claiming
    */
    modifier onlyFeeCollector() {
        _checkFeeCollector();
        _;
    }

    /*****************
    *   CONSTRUCTOR  *
    *****************/

    /**
    * @param _mailbox Hyperlane mailbox address
    * @param _startMintId min token ID that can be mined
    * @param _endMintId max token ID that can be mined
    * @param _mintFee fee amount to be sent as message value when calling the mint function
    * @param _bridgeFee fee amount to be sent as part of the value message when calling the mint function
    * @param _feeCollector the address to which the fee claiming is authorized
    */
    constructor(
        address _mailbox,
        uint256 _startMintId,
        uint256 _endMintId,
        uint256 _mintFee,
        uint256 _bridgeFee,
        address _feeCollector,
        uint256 _referralEarningBips
    ) HypERC721(_mailbox) {
        require(_startMintId < _endMintId, "Invalid mint range");
        require(_endMintId < type(uint256).max, "Incorrect max mint ID");
        require(_feeCollector != address(0), "Invalid fee collector address");
        require(_referralEarningBips <= FIFTY_PERCENT, "Invalid referral earning shares");
        startMintId = _startMintId;
        maxMintId = _endMintId;
        mintFee = _mintFee;
        bridgeFee = _bridgeFee;
        feeCollector = _feeCollector;
        referralEarningBips = _referralEarningBips;
        tokenCounter = _startMintId;
        init("L2PortalHypNFT", "HL2PT");
        
    }

     /***********************
    *   SETTERS / GETTERS  *
    ***********************/

    /**
    * @notice ADMIN Change minting fee
    * @param _mintFee new minting fee
    *
    * @dev emits {NogemHyper-MintFeeChanged}
    */
    function setMintFee(uint256 _mintFee) external onlyOwner {
        uint256 oldMintFee = mintFee;
        mintFee = _mintFee;
        emit MintFeeChanged(oldMintFee, _mintFee);
    }

    /**
    * @notice ADMIN Change bridge fee
    * @param _bridgeFee new bridge fee
    *
    * @dev emits {NogemHyper-BridgeFeeChanged}
    */
    function setBridgeFee(uint256 _bridgeFee) external onlyOwner {
        uint256 oldBridgeFee = bridgeFee;
        bridgeFee = _bridgeFee;
        emit BridgeFeeChanged(oldBridgeFee, _bridgeFee);
    }

    /**
    * @notice ADMIN Change referral earning share
    * @param _referralEarninBips new referral earning share
    *
    * @dev emits {NogemHyper-ReferralEarningBipsChanged}
    */
    function setReferralEarningBips(uint256 _referralEarninBips) external onlyOwner {
        _validate(_referralEarninBips <= FIFTY_PERCENT, ERROR_REFERRAL_BIPS_TOO_HIGH);
        uint256 oldReferralEarningsShareBips = referralEarningBips;
        referralEarningBips = _referralEarninBips;
        emit ReferralEarningBipsChanged(oldReferralEarningsShareBips, _referralEarninBips);
    }

    /**
    * @notice ADMIN Change referral earning share for specific referrer
    * @param referrer address for which a special share is set
    * @param earningBips new referral earning share for referrer
    *
    * @dev emits {NogemHyper-EarningBipsForReferrerChanged}
    */
    function setEarningBipsForReferrer(
        address referrer,
        uint256 earningBips
    ) external onlyOwner {
        _validate(earningBips <= ONE_HUNDRED_PERCENT, ERROR_REFERRAL_BIPS_TOO_HIGH);
        referrersEarningBips[referrer] = earningBips;
        emit EarningBipsForReferrerChanged(referrer, earningBips);
    }

    /**
    * @notice ADMIN Change referral earning share for specific referrers
    * @param referrers addresses for which a special share is set
    * @param earningBips new referral earning share for referrers
    *
    * @dev emits {NogemHyper-EarningBipsForReferrersChanged}
    */
    function setEarningBipsForReferrersBatch(
        address[] calldata referrers,
        uint256 earningBips
    ) external onlyOwner {
        _validate(earningBips <= ONE_HUNDRED_PERCENT, ERROR_REFERRAL_BIPS_TOO_HIGH);
        for (uint256 i; i < referrers.length; i++) {
            referrersEarningBips[referrers[i]] = earningBips;
        }
        emit EarningBipsForReferrersChanged(referrers, earningBips);
    }

    /**
    * @notice ADMIN Change fee collector address
    * @param _feeCollector new address for the collector
    *
    * @dev emits {NogemHyper-FeeCollectorChanged}
    */
    function setFeeCollector(address _feeCollector) external onlyOwner {
        _validate(_feeCollector != address(0), ERROR_INVALID_COLLECTOR_ADDRESS);
        address oldFeeCollector = feeCollector;
        feeCollector = _feeCollector;
        emit FeeCollectorChanged(oldFeeCollector, _feeCollector);
    }

    /**
    * @notice ADMIN Change base URI
    * @param _newTokenBaseURI new URI
    *
    * @dev emits {NogemHyper-TokenURIChanged}
    */
    function setTokenBaseURI(
        string calldata _newTokenBaseURI
    ) external onlyOwner {
        _validate(!tokenBaseURILocked, ERROR_INVALID_URI_LOCK_STATE);
        string memory oldTokenBaseURI = _tokenBaseURI;
        _tokenBaseURI = _newTokenBaseURI;
        emit TokenURIChanged(oldTokenBaseURI, _newTokenBaseURI);
    }

    /**
    * @notice ADMIN Lock / unlock base URI
    * @param locked lock token URI if true, unlock otherwise
    *
    * @dev emits {NogemHyper-TokenURILocked}
    */
    function setTokenBaseURILocked(bool locked) external onlyOwner {
        _validate(tokenBaseURILocked != locked, ERROR_INVALID_URI_LOCK_STATE);
        tokenBaseURILocked = locked;
        emit TokenURILocked(locked);
    }

    /**
    * @notice Retrieving token URI
    *
    * @dev emits {NogemHyper-TokenURILocked}
    */
    function tokenURI() public view returns (string memory) {
        return _tokenBaseURI;
    }

    /************
    *   MINT    *
    ************/

    /**
    * @notice Mint new L2Portal HypNFT
    *
    * @dev new token ID must be in range [startMintId - maxMintId]
    * @dev tx value must be equal to mintFee. See {NogemHyper-mintFee}
    * @dev emits {NogemHyper-HypNFTMinted}
    */
    function mint() external payable nonReentrant {
        uint256 newItemId = tokenCounter;
        uint256 feeEarnings = mintFee;

        _validate(newItemId < maxMintId, ERROR_MINT_EXCEEDS_LIMIT);
        _validate(msg.value >= feeEarnings, ERROR_MINT_INVALID_FEE);

        ++tokenCounter;

        feeEarnedAmount += feeEarnings;

        _safeMint(_msgSender(), newItemId);
        emit ONFTMinted(
            _msgSender(),
            newItemId,
            feeEarnings,
            address(0),
            0
        );
    }

    /**
    * @notice Mint new L2Portal ONFT by referral
    * @param referrer referral address
    *
    * @dev new token ID must be in range [startMintId - maxMintId]
    * @dev tx value must be equal to mintFee. See {NogemHyper-mintFee}
    * @dev referrer address must be non-zero
    * @dev emits {NogemHyper-ONFTMinted}
    */
    function mint(address referrer) public payable nonReentrant {
        uint256 newItemId = tokenCounter;
        uint256 _mintFee = mintFee;

        _validate(newItemId < maxMintId, ERROR_MINT_EXCEEDS_LIMIT);
        _validate(msg.value >= _mintFee, ERROR_MINT_INVALID_FEE);
        _validate(referrer != _msgSender() && referrer != address(0), ERROR_INVALID_REFERER);

        ++tokenCounter;

        uint256 referrerBips = referrersEarningBips[referrer];
        uint256 referrerShareBips = referrerBips == 0
            ? referralEarningBips
            : referrerBips;
        uint256 referrerEarnings = (_mintFee * referrerShareBips) / DENOMINATOR;
        uint256 feeEarnings = _mintFee - referrerEarnings;

        referrersEarnedAmount[referrer] += referrerEarnings;
        ++referredTransactionsCount[referrer];

        feeEarnedAmount += feeEarnings;

        _safeMint(_msgSender(), newItemId);
        emit ONFTMinted(
            _msgSender(),
            newItemId,
            feeEarnings,
            referrer,
            referrerEarnings
        );
    }


    /**************
    *   BRIDGE    *
    **************/

    /**
     * @notice Transfers `_amountOrId` token to `_recipient` on `_destination` domain.
     * @dev Delegates transfer logic to `_transferFromSender` implementation.
     * @dev Emits `SentTransferRemote` event on the origin chain.
     * @param _destination The identifier of the destination chain.
     * @param _recipient The address of the recipient on the destination chain.
     * @param _amountOrId The amount or identifier of tokens to be sent to the remote recipient.
     * @return messageId The identifier of the dispatched message.
     */
     
    function transferRemote(
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amountOrId
    ) external payable virtual override returns (bytes32 messageId){

        uint256 _bridgeFee = bridgeFee;
        uint256 _nativeFee = msg.value - _bridgeFee;

        feeEarnedAmount += _bridgeFee;
        bytes32 _messageId = _transferRemote(_destination, _recipient, _amountOrId, _nativeFee);

        emit BridgeFeeEarned(_recipient, _destination, _bridgeFee);

        return _messageId;
    }

     /*************
    *   CLAIM    *
    *************/

    /**
    * @notice FEE_COLLECTOR Claim earned fee (mint + bridge)
    *
    * @dev earned amount must be more than zero to claim
    * @dev emits {NogemHyper-FeeEarningsClaimed}
    */
    function claimFeeEarnings() external onlyFeeCollector nonReentrant {
        uint256 _feeEarnedAmount = feeEarnedAmount;
        _validate(_feeEarnedAmount != 0, ERROR_NOTHING_TO_CLAIM);

        uint256 currentEarnings = _feeEarnedAmount;
        feeEarnedAmount = 0;
        feeClaimedAmount += currentEarnings;

        address _feeCollector = feeCollector;
        (bool success, ) = payable(_feeCollector).call{value: currentEarnings}("");
        require(success, "Failed to send Ether");
        emit FeeEarningsClaimed(_feeCollector, currentEarnings);
    }

    /**
    * @notice Claim earned fee from referral mint
    *
    * @dev earned amount must be more than zero to claim
    * @dev emits {NogemHyper-ReferrerEarningsClaimed}
    */
    function claimReferrerEarnings() external {
        uint256 earnings = referrersEarnedAmount[_msgSender()];
        _validate(earnings != 0, ERROR_NOTHING_TO_CLAIM);

        referrersEarnedAmount[_msgSender()] = 0;
        referrersClaimedAmount[_msgSender()] += earnings;

        (bool sent, ) = payable(_msgSender()).call{value: earnings}("");
        require(sent, "Failed to send Ether");

        emit ReferrerEarningsClaimed(_msgSender(), earnings);
    }

    /***************
    *   HELPERS    *
    ***************/

    /**
    * @notice Checks if address is current fee collector
    */
    function _checkFeeCollector() internal view {
        _validate(feeCollector == _msgSender(), ERROR_NOT_FEE_COLLECTOR);
    }

    /**
    * @notice Mimics the initialize function in HypERC72
    */

    function init(
        string memory _name,
        string memory _symbol
    ) internal initializer {
        __ERC721_init(_name, _symbol);
    }

    /**
    * @notice Checks if the condition is met and reverts with an error if not
    * @param _clause condition to be checked
    * @param _errorCode code that will be passed in the error
    */
    function _validate(bool _clause, uint8 _errorCode) internal pure {
        if (!_clause) revert L2PortalHypNFT721_CoreError(_errorCode);
    }
}
