pragma solidity ^0.5.8;

// To enable ability to return Flight struct in memory
// TODO: DO NOT use in production deployment
pragma experimental ABIEncoderV2;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyLib.sol";

contract FlightSuretyData {
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

    using FlightSuretyLib for FlightSuretyLib.FlightSurety;
    FlightSuretyLib.FlightSurety private flightSurety;

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
    modifier requireOperational()
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
    modifier requireAuthorized()
    {
        require(authorizedContracts[msg.sender] == true || msg.sender == contractOwner, "Caller is not authorized");
        _;
    }


    /**
    * @dev Modifier that requires the airline to valid
    */
    modifier requireAirline(address airline)
    {
        require(airline != address(0) && flightSurety.airlines[airline].nonce > 0, "airline not found.");
        _;
    }


    /**
    * @dev Modifier that requires the flight to valid
    */
    modifier requireFlight(address airline, bytes32 key)
    {
        require(flightSurety.airlines[airline].flights[key].nonce > 0, "not a valid flight key.");
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
                        requireAuthorized
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
                            address airline
                        )
                        external
                        view
                        requireAuthorized
                        returns(bool)
    {
        require(airline != address(0), "must be a valid address.");

        return (flightSurety.airlines[airline].nonce > 0) ? true : false;
    }


    /**
     * @dev Determines if Airline is registered
     */
    function isRegistered
                        (
                            address airline
                        )
                        external
                        view
                        requireAuthorized
                        returns(bool)
    {
        require(airline != address(0), "must be a valid address.");

        return flightSurety.airlines[airline].registered;
    }


    /**
     * @dev Determines if Airline is funded
     */
    function isFunded
                        (
                            address airline
                        )
                        external
                        view
                        requireAuthorized
                        returns(bool)
    {
        require(airline != address(0), "must be a valid address.");

        return flightSurety.airlines[airline].funded;
    }


    /**
     * @dev Determines if Flight has been registered to Airline
     */
    function isFlight
                        (
                            address airline,
                            bytes32 key
                        )
                        external
                        view
                        requireAuthorized
                        returns(bool)
    {
        require(airline != address(0), "must be a valid address.");

        return (flightSurety.airlines[airline].flights[key].nonce > 0);
    }


    /**
     * @dev Get the number of currently registered airlines
     */
    function getRegistrationCount
                        (
                        )
                        external
                        view
                        requireAuthorized
                        returns(uint)
    {
        return registeredAirlines;
    }


    /**
     * @dev Get the number of currently registered airlines
     */
    function getVoteCount
                        (
                            address airline
                        )
                        external
                        view
                        requireAuthorized
                        returns(uint)
    {
        return flightSurety.airlines[airline].votes;
    }


   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function addAirline
                            (
                                address airline,
                                string calldata airlineName
                            )
                            external
                            requireAuthorized
    {
        require(airline != address(0), "must be a valid address.");
        require(flightSurety.airlines[airline].nonce == 0, "airline already added.");

        flightSurety.airlines[airline] = FlightSuretyLib.Airline({
                                nonce: airlineNonce,
                                name: airlineName,
                                registered: false,
                                funded: false,
                                votes: 0,
                                flightNonce: 0
                            });

        airlineNonce = airlineNonce.add(1);
    }


   /**
    * @dev add vote for an airline registration
    *   Returns the # of registrations in the contract
    *   and the # of votes this airline has received
    *
    */
    function addVote
                    (
                        address airline
                    )
                    external
                    requireAuthorized
                    requireAirline(airline)
                    returns
                    (
                        uint,
                        uint
                    )
    {
        flightSurety.airlines[airline].votes = flightSurety.airlines[airline].votes.add(1);

        // # of registered airlines and # of votes for this airline
        return(registeredAirlines, flightSurety.airlines[airline].votes);
    }


    /**
    * @dev approve airline registration
    *   Marks the airline as 'registered' and increments the total number of registered airlines for the contract
    *
    */
    function approveAirline
                    (
                        address airline
                    )
                    external
                    requireAuthorized
                    requireAirline(airline)
    {
        flightSurety.airlines[airline].registered = true;
        registeredAirlines = registeredAirlines.add(1);
    }


    /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function addFunds
                            (
                                address airline
                            )
                            public
                            payable
                            requireAuthorized
                            requireAirline(airline)
    {
        balance = balance.add(msg.value);
        flightSurety.airlines[airline].funded = true;
    }


    /**
    * @dev Add a flight to the Flight mappings
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function addFlight
                            (
                                address airline,
                                string calldata _code,
                                string calldata _origin,
                                uint256 _departureTimestamp,
                                string calldata _destination,
                                uint256 _arrivalTimestamp
                            )
                            external
                            requireAuthorized
                            requireAirline(airline)
                            returns(uint _nonce, bytes32 _key)
    {
        _key = this.createFlightKey(airline, _code, _departureTimestamp, _arrivalTimestamp);

        flightSurety.airlines[airline].flightNonce = flightSurety.airlines[airline].flightNonce.add(1);
        _nonce = flightSurety.airlines[airline].flightNonce;

        flightSurety.airlines[airline].flightKeys[_nonce] = _key;

        flightSurety.airlines[airline].flights[_key] = FlightSuretyLib.Flight({
                                                    nonce: _nonce,
                                                    key: _key,
                                                    code: _code,
                                                    origin: _origin,
                                                    departureTimestamp: _departureTimestamp,
                                                    destination: _destination,
                                                    arrivalTimestamp: _arrivalTimestamp,
                                                    statusCode: FlightSuretyLib.STATUS_CODE_UNKNOWN()
                                                });
    }


    /**
    * @dev Create a unique key for the flight, which is used to look it up in the mapping
    *
    */
    function createFlightKey
                        (
                            address airline,
                            string calldata code,
                            uint256 departureTimestamp,
                            uint256 arrivalTimestamp
                        )
                        external
                        view
                        requireAuthorized
                        returns(bytes32)
    {
        require(airline != address(0), "must be a valid address.");

        return keccak256(abi.encodePacked(airline, code, departureTimestamp, arrivalTimestamp));
    }


    /**
    * @dev Return 1st Airline flight
    *
    */
    function getFlight
                        (
                            address airline,
                            bytes32 key
                        )
                        external
                        view
                        requireAuthorized
                        requireAirline(airline)
                        requireFlight(airline, key)
                        returns(FlightSuretyLib.Flight memory flightInfo)
    {
        return flightSurety.airlines[airline].flights[key];
    }

    /**
    * @dev Get # of flights for Airline
    *
    */
    function getFlightNonce
                        (
                            address airline
                        )
                        external
                        view
                        requireAuthorized
                        requireAirline(airline)
                        returns(uint)
    {
        return flightSurety.airlines[airline].flightNonce;
    }

    /**
    * @dev Given a nonce, return the Flight Key
    *
    */
    function getFlightKey
                        (
                            address airline,
                            uint nonce
                        )
                        external
                        view
                        requireAuthorized
                        requireAirline(airline)
                        returns(bytes32)
    {
        require(nonce > 0 && nonce <= flightSurety.airlines[airline].flightNonce, "flight nonce out of range.");

        return flightSurety.airlines[airline].flightKeys[nonce];
    }

    /**
    * @dev Return 1st five Airline flights
    *
    */
    function getFlightList
                        (
                            address airline,
                            uint startNonce,
                            uint endNonce
                        )
                        external
                        view
                        requireAuthorized
                        returns(FlightSuretyLib.Flight[] memory)
    {
        FlightSuretyLib.Flight[] memory flightList = new FlightSuretyLib.Flight[](endNonce.sub(startNonce).add(1));

        uint index = 0;
        for (uint nonce = startNonce; nonce <= endNonce; nonce = nonce.add(1)) {
            bytes32 key = flightSurety.airlines[airline].flightKeys[nonce];
            flightList[index] = flightSurety.airlines[airline].flights[key];
            index = index.add(1);
        }

        return flightList;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */
    function buyFlightInsurance
                            (
                                address airline,
                                bytes32 key,
                                address passenger
                            )
                            external
                            payable
                            requireAuthorized
    {
        require(passenger != address(0), "passenger account must be a valid address");

        balance = balance.add(msg.value);

        // Add flight insurance for passenger
        flightSurety.flightInsurees[airline][key][passenger] = FlightSuretyLib.FlightInsurance
                                                                        ({
                                                                            purchased: msg.value,
                                                                            payout: 0,
                                                                            isInsured: true,
                                                                            isCredited: false,
                                                                            isWithdrawn: false
                                                                        });

        // Add to list of insured passengers
        flightSurety.insuredPassengers[airline][key].push(passenger);
    }


    /**
     *  @dev Get Passenger insurance information
    */
    function getPassengerInsurance
                                (
                                    address airline,
                                    bytes32 key,
                                    address passenger
                                )
                                external
                                view
                                requireAuthorized
                                returns(FlightSuretyLib.FlightInsurance memory insuree)
    {
        require(passenger != address(0), "passenger account must be a valid address");

        return flightSurety.flightInsurees[airline][key][passenger];
    }


    /**
     *  @dev Get insured passengers for airline/flight
    */
    function getInsuredPassengers
                            (
                                address airline,
                                bytes32 key
                            )
                            external
                            view
                            requireAuthorized
                            returns(address[] memory passengers)
    {
        return flightSurety.insuredPassengers[airline][key];
    }


    /**
     *  @dev Credit payout to Flight Insuree
    */
    function creditFlightInsuree
                                (
                                    address airline,
                                    bytes32 key,
                                    address passenger,
                                    uint amountToPayout
                                )
                                external
                                requireAuthorized
    {
        require(passenger != address(0), "passenger not found.");

        uint amount = flightSurety.flightInsurees[airline][key][passenger].payout.add(amountToPayout);

        flightSurety.flightInsurees[airline][key][passenger].payout = amount;
        flightSurety.flightInsurees[airline][key][passenger].isCredited = true;
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function payFlightInsuree
                            (
                                address airline,
                                bytes32 key,
                                address payable passenger
                            )
                            external
                            requireAuthorized
                            returns(uint amountWithdrawn)
    {
        require(passenger != address(0), "passenger not found.");
        require(balance >= flightSurety.flightInsurees[airline][key][passenger].payout, "insufficient contract funds.");
        require(flightSurety.flightInsurees[airline][key][passenger].payout > 0, "no payout available.");

        amountWithdrawn = flightSurety.flightInsurees[airline][key][passenger].payout;
        balance = balance.sub(amountWithdrawn);

        flightSurety.flightInsurees[airline][key][passenger].purchased = 0;
        flightSurety.flightInsurees[airline][key][passenger].payout = 0;
        flightSurety.flightInsurees[airline][key][passenger].isInsured = false;
        flightSurety.flightInsurees[airline][key][passenger].isCredited = false;
        flightSurety.flightInsurees[airline][key][passenger].isWithdrawn = true;

        passenger.transfer(amountWithdrawn);
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
                            requireOperational
    {
        balance = balance.add(msg.value);
    }
}

