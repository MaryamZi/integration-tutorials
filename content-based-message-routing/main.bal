import ballerina/http;
import ballerina/log;

configurable int port = 8290;

final http:Client grandOakEP = check initializeHttpClient("http://localhost:9090/grandoaks/categories");
final http:Client clemencyEP = check initializeHttpClient("http://localhost:9090/clemency/categories");
final http:Client pineValleyEP = check initializeHttpClient("http://localhost:9090/pinevalley/categories");

function initializeHttpClient(string url) returns http:Client|error => new (url);

type Patient record {|
    string name;
    string dob;
    string ssn;
    string address;
    string phone;
    string email;
|};

type ReservationRequest record {|
    Patient patient;
    string doctor;
    string hospital_id;
    string hospital;
    string appointment_date;
|};

type Doctor record {|
    string name;
    string hospital;
    string category;
    string availability;
    float fee;
|};

type ReservationResponse record {|
    int appointmentNumber;
    Doctor doctor;
    Patient patient;
    float fee;
    string hospital;
    boolean confirmed;
    string appointmentDate;
|};

enum HospitalIds {
    GRANDOAKS = "grandoaks",
    CLEMENCY = "clemency",
    PINEVALLEY = "pinevalley"
};

service /healthcare on new http:Listener(port) {
    resource function post categories/[string category]/reserve(ReservationRequest payload)
            returns ReservationResponse|http:NotFound|http:BadRequest|http:InternalServerError {
        ReservationRequest {hospital_id, patient, ...reservationRequest} = payload;
        http:Client hospitalEP;
        match hospital_id {
            GRANDOAKS => {
                log:printInfo("Routed to Grand Oak Community Hospital");
                hospitalEP = grandOakEP;
            }
            CLEMENCY => {
                log:printInfo("Routed to Clemency Medical Center");
                hospitalEP = clemencyEP;
            }
            _ => {
                log:printInfo("Routed to Pine Valley Community Hospital");
                hospitalEP = pineValleyEP;
            }
        }

        ReservationResponse|http:ClientError resp = hospitalEP->/[category]/reserve.post({
            patient,
            ...reservationRequest
        });

        if resp is ReservationResponse {
            log:printDebug("Reservation request successful",
                            name = patient.name,
                            appointmentNumber = resp.appointmentNumber);
            return resp;
        }

        log:printError("Reservation request failed", resp);
        if resp is http:ClientRequestError {
            return <http:NotFound> {body: "Unknown hospital, doctor or category"};
        }

        return <http:InternalServerError> {body: resp.message()};
    }
}
