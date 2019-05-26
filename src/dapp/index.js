
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let flightList = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            status('Operational Status', result ? 'UP' : 'DOWN', []);
            if (error) {
                display('Operations', 'Status', [ { label: 'Unknown Error', error: error, value: 'must be in test mode'} ]);
            }
        });

        // Get Flights 
        // For now we're just getting a set of flights from the 1st airline registered when the contracts were deployed:
        //  Delta
        contract.getFlightList(contract.airlines[0], (error, results) => {
            flightList = results;

            let select = DOM.elid('passenger-flight-list');
            DOM.appendOptions(select, flightList, (flightInfo) => {
                return { key: flightInfo[1], code: flightInfo[2] };
            });

            select = DOM.elid('oracle-flight-list');
            DOM.appendOptions(select, flightList, (flightInfo) => {
                return { key: flightInfo[1], code: flightInfo[2] };
            });
        });

        //
        // Setup events to watch for

        // FlightInsurancePurchased event
        contract.FlightInsurancePurchased((error, event) => {
            event.returnValues['blockNumber'] = event.blockNumber;
            display('Flight Events', 'FlightInsurancePurchased', [ { label: 'Result', error: error, value: event.returnValues } ]);
        });
        // FlightRegistered event
        contract.FlightRegistered((error, event) => {
            event.returnValues['blockNumber'] = event.blockNumber;
            display('Flight Events', 'FlightRegistered', [ { label: 'Result', error: error, value: event.returnValues} ]);
        });
        // OracleRegistered event
        /*
        contract.OracleRegistered((error, event) => {
            event.returnValues['blockNumber'] = event.blockNumber;
            display('Oracle Events', 'OracleRegistered', [ { label: 'Result', error: error, value: event.returnValues} ]);
        });
        */
        // OracleRequest event
        contract.OracleRequest((error, event) => {
            event.returnValues['blockNumber'] = event.blockNumber;
            display('Oracle Events', 'OracleRequest', [ { label: 'Result', error: error, value: event.returnValues} ]);
        })
        // FlightStatusInfo event
        contract.FlightStatusInfo((error, event) => {
            event.returnValues['blockNumber'] = event.blockNumber;
            display('Oracle Events', 'FlightStatusInfo', [ { label: 'Result', error: error, value: event.returnValues} ]);
        })
        // FlightDelayed event
        contract.FlightDelayed((error, event) => {
            event.returnValues['blockNumber'] = event.blockNumber;
            display('Flight Events', 'FlightDelayed', [ { label: 'Result', error: error, value: event.returnValues} ]);
        })
        // InsuredPassengerPayout event
        contract.InsuredPassengerPayout((error, event) => {
            event.returnValues['blockNumber'] = event.blockNumber;
            display('Passenger Events', 'InsuredPassengerPayout', [ { label: 'Result', error: error, value: event.returnValues} ]);
        })    
        // PassengerInsuranceWithdrawal event
        contract.PassengerInsuranceWithdrawal((error, event) => {
            event.returnValues['blockNumber'] = event.blockNumber;
            display('Passenger Events', 'PassengerInsuranceWithdrawal', [ { label: 'Result', error: error, value: event.returnValues} ]);
        })

        // Clear contract messages (except for operational status)
        DOM.elid('clear-display').addEventListener('click', () => {
            let node = DOM.elid('info-wrapper');
            DOM.clear(node);
        });

        // Get data contract balance
        DOM.elid('submit-get-balance').addEventListener('click', () => {
            // Write transaction
            contract.getBalance((error, result) => {
                display('Contracts', 'Get Balance', [ { label: 'Result', error: error, value: result} ]);
            });
        });
    
        // Register airline - submit for approval
        // If # of existing airlines < 5, airline is automatically approved and registered
        // Otherwise airline must receive 50% of the vote to be registered
        DOM.elid('submit-register-airline').addEventListener('click', () => {
            let airline = DOM.elid('airline-address').value;
            let name = DOM.elid('airline-name').value;
            // Write transaction
            contract.registerAirline(airline, name, (error, result) => {
                display('Airlines', 'Register Airline', [ { label: 'Result', error: error, value: result} ]);
            });
        });

        // Airline sends funds - to participate in contract
        // The dApp uses the 'airline-address' as the 'from' to send 10 Ether to the contract
        DOM.elid('submit-funds-airline').addEventListener('click', () => {
            let airline = DOM.elid('airline-address').value;
            // Write transaction
            contract.fundAirline(airline, (error, result) => {
                display('Airlines', 'Fund Airline', [ { label: 'Result', error: error, value: result} ]);
            });
        });

        // Airline registers a flight - must be funded 1st
        // The dApp uses the 'airline-address' as the 'from' to send 10 Ether to the contract
        DOM.elid('submit-register-flight').addEventListener('click', () => {
            let airline = DOM.elid('flight-airline').value;
            let flight = DOM.elid('flight-number').value;
            let origin = DOM.elid('flight-origin').value;
            let departure = DOM.elid('flight-departure').value;
            let destination = DOM.elid('flight-destination').value;
            let arrival = DOM.elid('flight-arrival').value;

            // Do the register flight transaction
            contract.registerFlight(airline, flight, origin, departure, destination, arrival, (error, result) => {
                display('Flights', 'Register Flight', [ { label: 'Result', error: error, value: result} ]);
            });
        });

        // Purchase insurance
        DOM.elid('submit-purchase-insurance').addEventListener('click', () => {
            let select = DOM.elid('passenger-flight-list');
            let key = DOM.selectedOption(select.children);
            let amount = DOM.elid('passenger-insurance').value;
            let passenger = contract.passengers[0];

            if (amount > 1) {
                display('Flights', 'Purchase Insurance', [ { label: 'Validation Error', error: '', value: 'insurance amount must be <= 1 ether'} ]);
            } else {
                // Do the purchase insurance transaction
                contract.purchaseInsurance(key, amount, passenger, (error, result) => {
                    display('Flights', 'Purchase Insurance', [ { label: 'Result', error: error, value: result} ]);
                });
            }
        });

        // Withdraw insurance payout
        DOM.elid('submit-withdraw-payout').addEventListener('click', () => {
            let select = DOM.elid('passenger-flight-list');
            let key = DOM.selectedOption(select.children);
            let passenger = contract.passengers[0];

            // Do the insurance withdrawal
            contract.payFlightInsuree(key, passenger, (error, result) => {
                display('Passengers', 'Pay Flight Insuree', [ { label: 'Result', error: error, value: result} ]);
            });
        });


        // Withdraw insurance payout
        // TODO: submit withdraw payout to App contract

        // Fetch flight status - submit to Oracles transaction
        DOM.elid('submit-oracle-flight').addEventListener('click', () => {
            let select = DOM.elid('oracle-flight-list');
            let key = DOM.selectedOption(select.children);
            // Write transaction
            contract.fetchFlightStatus(key, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Flight Status Request', error: error, value: result} ]);
            });
        });
    
    }); 

})();

function status(title, description, results) {
    let displayDiv = DOM.elid("status-wrapper");
    let section = DOM.section();

    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));

    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);
}

function display(title, description, results) {
    let displayDiv = DOM.elid("info-wrapper");
    let section = DOM.section();

    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));

    results.map((result) => {   
        let row = section.appendChild(DOM.div({className:'row'}));

        if (result.error) {
            row.appendChild(DOM.div({className: 'col-sm-2 field'}, result.label));
            row.appendChild(DOM.div({className: 'col-sm-10 field-value'}, String(result.error)));
        }

        // If result contains an error, there won't be a value
        if (result.value === null)
            return;
     
        if (typeof result.value === 'object') {
            // convert event object to array of event info
            // https://stackoverflow.com/questions/38824349/how-to-convert-an-object-to-an-array-of-key-value-pairs-in-javascript
            let resultInfo = Object.keys(result.value).map(function(key) {
                
                // Don't process keys that contain numbers
                if (!hasNumber(key)) {
                    row.appendChild(DOM.div({className: 'col-sm-2 field'}, key));
                    row.appendChild(DOM.div({className: 'col-sm-10 field-value'}, String(result.value[key])));
                    section.appendChild(row);
                }
            });
        } else {
            row.appendChild(DOM.div({className: 'col-sm-10 field-value'}, String(result.value)));
        }
        
        section.appendChild(row);
    })
    displayDiv.append(section);
    
    top();
}

// https://www.w3schools.com/howto/howto_js_scroll_to_top.asp
// Scroll to the top of the document
function top() {
    document.body.scrollTop = 0; // For Safari
    document.documentElement.scrollTop = 0; // For Chrome, Firefox, IE and Opera
}

//https://stackoverflow.com/questions/5778020/check-whether-an-input-string-contains-a-number-in-javascript/5778071
function hasNumber(value) {
    return /\d/.test(value);
}






