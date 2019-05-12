pragma solidity ^0.5.8;

// To enable ability to return Flight struct in memory
// TODO: DO NOT use in production deployment
pragma experimental ABIEncoderV2;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyBase.sol";

contract FlightSuretyData is FlightSuretyBase {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                              // Account used to deploy contract
    bool private operational = true;                            // Blocks all state changes throughout the contract if false

    uint balance;                                               // Records the contract balance

    uint private registeredAirlines = 0;                        // Number of airlines registered with the contract
    uint private airlineNonce = 1;                              // Starting airline nonce

    mapping(address => bool) private authorizedContracts;       // Mapping for contracts authorized to call data contract

    struct Airline {
        uint nonce;                                             // Airline nonce or unique #
        string name;
        bool registered;
        bool funded;
        uint votes;
        uint flightNonce;                                       // to keep track of current # of registered flights for the Airline
        mapping(uint => bytes32) flightKeys;                    // mapping for flight index to flight key
        mapping(bytes32 => Flight) flights;
    }

    // Mapping for airline account and all relevant info, including flights
    mapping(address => Airline) private airlines;

    // Mapping for passenger account and flight insurance info
    // Each passenger account points to another mapping of: flight key => FlightInsurance
    // The data structure is designed with the idea that insurance information will be obtained using the flight key
    mapping(address => mapping(bytes32 => FlightInsurance)) private passengers;

    // Mapping that enables crediting insurees by flight
    mapping(bytes32 => address[]) private insurees;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                )
                                public
    {
        contractOwner = msg.sender;

        // Add our self to authorized contracts for calling methods that are 'external'
        authorizedContracts[address(this)] = true;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
        require(operational, "Contract is not operational");
        _;
    }


    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }


    /**
    * @dev Modifier that requires the function caller to be authorized
    */
    modifier isAuthorized()
    {
        require(authorizedContracts[msg.sender] == true || msg.sender == contractOwner, "Caller is not authorized");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational()
                            public
                            view
                            returns(bool)
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus
                            (
                                bool mode
                            )
                            external
                            requireContractOwner
    {
        operational = mode;
    }


    function authorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        require(contractAddress != address(0), "must be a valid address.");
        require(!authorizedContracts[contractAddress], "Caller is already authorized.");
        authorizedContracts[contractAddress] = true;
    }


    function deauthorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        require(contractAddress != address(0), "must be a valid address.");
        require(authorizedContracts[contractAddress] == true, "Caller has not been authorized.");
        delete authorizedContracts[contractAddress];
    }


    function getBalance
                        (
                        )
                        external
                        view
                        returns (uint)
    {
        return balance;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Determines if Airline is registered
     */
    function isAirline
                        (
                            address _airline
                        )
                        external
                        view
                        isAuthorized
                        returns(bool)
    {
        require(_airline != address(0), "must be a valid address.");
        return (airlines[_airline].nonce > 0) ? true : false;
    }


    /**
     * @dev Determines if Airline is registered
     */
    function isRegistered
                        (
                            address _airline
                        )
                        external
                        view
                        isAuthorized
                        returns(bool)
    {
        require(_airline != address(0), "must be a valid address.");
        return airlines[_airline].registered;
    }


    /**
     * @dev Determines if Airline is funded
     */
    function isFunded
                        (
                            address _airline
                        )
                        external
                        view
                        isAuthorized
                        returns(bool)
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce > 0, "airline not found.");

        return airlines[_airline].funded;
    }


    /**
     * @dev Determines if Flight has been registered to Airline
     */
    function isFlight
                        (
                            address _airline,
                            bytes32 _flightKey
                        )
                        external
                        view
                        isAuthorized
                        returns(bool)
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce > 0, "airline not found.");

        return (airlines[_airline].flights[_flightKey].nonce > 0);
    }


    /**
     * @dev Get the number of currently registered airlines
     */
    function getRegistrationCount
                        (
                        )
                        external
                        view
                        isAuthorized
                        returns(uint)
    {
        return registeredAirlines;
    }


    /**
     * @dev Get the number of currently registered airlines
     */
    function getVoteCount
                        (
                            address _airline
                        )
                        external
                        view
                        isAuthorized
                        returns(uint)
    {
        return airlines[_airline].votes;
    }


   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function addAirline
                            (
                                address _airline,
                                string calldata _name
                            )
                            external
                            isAuthorized
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce == 0, "airline already added.");

        airlines[_airline] = Airline({
                                nonce: airlineNonce++,
                                name: _name,
                                registered: false,
                                funded: false,
                                votes: 0,
                                flightNonce: 0
                            });
    }


   /**
    * @dev add vote for an airline registration
    *   Returns the # of registrations in the contract
    *   and the # of votes this airline has received
    *
    */
    function addVote
                    (
                        address _airline
                    )
                    external
                    isAuthorized
                    returns
                    (
                        uint,
                        uint
                    )
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce > 0, "airline not found.");

        airlines[_airline].votes++;

        // # of registered airlines and # of votes for this airline
        return(registeredAirlines, airlines[_airline].votes);
    }


    /**
    * @dev approve airline registration
    *   Marks the airline as 'registered' and increments the total number of registered airlines for the contract
    *
    */
    function approveAirline
                    (
                        address _airline
                    )
                    external
                    isAuthorized
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce > 0, "airline not found.");

        airlines[_airline].registered = true;
        registeredAirlines++;
    }


    /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function addFunds
                            (
                                address _airline
                            )
                            public
                            payable
                            isAuthorized
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce > 0, "airline not found.");

        balance += msg.value;
        airlines[_airline].funded = true;
    }


    /**
    * @dev Add a flight to the Flight mappings
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function addFlight
                            (
                                address _airline,
                                string calldata _flight,
                                string calldata _origin,
                                uint256 _departureTimestamp,
                                string calldata _destination,
                                uint256 _arrivalTimestamp
                            )
                            external
                            isAuthorized
                            returns(uint flightNonce, bytes32 flightKey)
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce > 0, "airline not found.");

        flightKey = this.createFlightKey(_airline, _flight, _departureTimestamp, _arrivalTimestamp);

        flightNonce = ++airlines[_airline].flightNonce;

        airlines[_airline].flightKeys[flightNonce] = flightKey;

        airlines[_airline].flights[flightKey] = Flight({
                                                    nonce: flightNonce,
                                                    flight: _flight,
                                                    origin: _origin,
                                                    departureTimestamp: _departureTimestamp,
                                                    destination: _destination,
                                                    arrivalTimestamp: _arrivalTimestamp,
                                                    statusCode: STATUS_CODE_UNKNOWN
                                                });
    }


    /**
    * @dev Create a unique key for the flight, which is used to look it up in the mapping
    *
    */
    function createFlightKey
                        (
                            address _airline,
                            string calldata _flight,
                            uint256 _departureTimestamp,
                            uint256 _arrivalTimestamp
                        )
                        external
                        view
                        isAuthorized
                        returns(bytes32)
    {
        require(_airline != address(0), "must be a valid address.");

        return keccak256(abi.encodePacked(_airline, _flight, _departureTimestamp, _arrivalTimestamp));
    }


    /**
    * @dev Return 1st Airline flight
    *
    */
    function getFlight
                        (
                            address _airline,
                            bytes32 _flightKey
                        )
                        external
                        view
                        isAuthorized
                        returns(Flight memory flightInfo)
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce > 0, "airline not found.");
        require(airlines[_airline].flights[_flightKey].nonce > 0, "not a valid flight key.");

        return airlines[_airline].flights[_flightKey];
    }

    /**
    * @dev Get # of flights for Airline
    *
    */
    function getFlightNonce
                        (
                            address _airline
                        )
                        external
                        view
                        isAuthorized
                        returns(uint)
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce > 0, "airline not found.");

        return airlines[_airline].flightNonce;
    }

    /**
    * @dev Given a nonce, return the Flight Key
    *
    */
    function getFlightKey
                        (
                            address _airline,
                            uint _nonce
                        )
                        external
                        view
                        isAuthorized
                        returns(bytes32)
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce > 0, "airline not found.");
        require(_nonce > 0 && _nonce <= airlines[_airline].flightNonce, "flight nonce out of range.");

        return airlines[_airline].flightKeys[_nonce];
    }

    /**
    * @dev Return 1st five Airline flights
    *
    */
    function getFlightList
                        (
                            address _airline,
                            uint _startNonce,
                            uint _endNonce
                        )
                        external
                        view
                        isAuthorized
                        returns(Flight[] memory)
    {
        require(_airline != address(0), "must be a valid address.");
        require(airlines[_airline].nonce > 0, "airline not found.");
        require(_startNonce > 0 && _startNonce <= airlines[_airline].flightNonce, "flight start nonce out of range.");
        require(_startNonce < _endNonce, "flight start nonce must be < end nonce.");
        require(_endNonce > 0 && _endNonce <= airlines[_airline].flightNonce, "flight end nonce out of range.");

        Flight[] memory flightList = new Flight[](_endNonce - _startNonce + 1);

        uint8 index = 0;
        for (uint nonce = _startNonce; nonce <= _endNonce; nonce++) {
            bytes32 flightKey = airlines[_airline].flightKeys[nonce];
            flightList[index++] = airlines[_airline].flights[flightKey];
        }

        return flightList;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */
    function buyFlightInsurance
                            (
                                address _passenger,
                                address _airline,
                                bytes32 _flightKey
                            )
                            external
                            payable
                            isAuthorized
    {
        require(_airline != address(0), "must be a valid airline address.");
        require(airlines[_airline].nonce > 0, "airline not found.");
        require(_passenger != address(0), "passenger account must be a valid address");

        balance += msg.value;


    }


    /**
     *  @dev Credits payouts to insurees
    */
    function creditFlightInsurees
                                (
                                )
                                external
                                view
                                isAuthorized
    {

    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function payFlightInsuree
                            (
                            )
                            external
                            view
                            isAuthorized
    {
    }


    /**
    * @dev Fallback function for funding smart contract.
    *
    *   Can only be called by the contract owner. The App contract will call the fund() method
    *   and pass the valid Airline account so it can be credited properly.
    *
    *   NOTE: the fallback function could be used by the contract owner to setup intial
    *   funding of the FlightSurety insurance program.
    */
    function()
                            external
                            payable
                            requireContractOwner
                            requireIsOperational
    {
    }
}

