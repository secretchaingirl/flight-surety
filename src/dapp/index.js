
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let flightInfos = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            status('Operational Status', result ? 'UP' : 'DOWN', []);
            if (error) {
                display('Operations', 'Status', [ { label: 'Unknown Error', error: error, value: 'must be in test mode'} ]);
            }
        });

        // Get Flights 
        contract.getFlightInfos((error, results) => {
            flightInfos = results;

            let select = DOM.elid('flight-infos');
            DOM.appendOptions(select, flightInfos, (flightInfo) => {
                return flightInfo[2];
            });
        });

        //
        // Setup event listening
        //

        // Purchase insurance
        DOM.elid('submit-purchase-insurance').addEventListener('click', () => {
            let select = DOM.elid('flight-infos');
            let flight = DOM.selectedOption(select.children);
            let insuranceEther = DOM.elid('passenger-insurance').value;

            if (insuranceEther > 1) {
                display('Flights', 'Purchase Insurance', [ { label: 'Validation Error', error: '', value: 'insurance amount must be <= 1 ether'} ]);
            } else {
                // TODO: contract.purchaseInsurance() - go through flightInfos to get match
                contract.purchaseInsurance(flight, insuranceEther, (error, result) => {
                    display('Flights', 'Purchase Insurance', [ { label: 'Result', error: error, value: result} ]);
                });
            }
        });

        // Clear contract messages (except for operational status)
        DOM.elid('clear-display').addEventListener('click', () => {
            let node = DOM.elid('info-wrapper');
            DOM.clear(node);
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
            // Write transaction
            contract.registerFlight(airline, flight, origin, departure, destination, arrival, (error, result) => {
                display('Flights', 'Register Flight', [ { label: 'Result', error: error, value: result} ]);
            });
        });

        // Fetch flight status - submit to Oracles transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
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
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
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






