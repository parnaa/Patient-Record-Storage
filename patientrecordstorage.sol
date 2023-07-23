//SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.18;

contract patientRecordStorage{
     
   
    struct Doctor{
        string name;
        string qualification;
        string workPlace;
        string specialization;
        bool exists;
    }
    enum medicine_dosage{
        OD, BD, TDS, SOS //0: OD, 1: BD, 2: TDS, 3: SOS
    }
    enum medicine_timing{
        Before_Meal, After_Meal //0:Before_Meal, 1: After_Meal
    }
    struct Medicine{
        string name;
        bool continue_status;
        medicine_dosage dosage;
        medicine_timing dosageTiming;
        bool exists;
    }
    

    struct Patient{
        string name;
        uint256  dateofbirth; //dob timestamp will be stored
        uint256 weight; // in kg
        uint256 height; // in cm
        Disease[] disease;
        Medicine[] allergic_to; //list of medicines the patient is allergic to 
        mapping (address => bool) approved_editors; //If a person is approved to change few records of Patient
        mapping (address => Medicine[]) current_medications; //which doctor prescribed which medicine lists 
        bool exists;
    }

   enum RecoveryStatus{
       NotTreated, UnderTreatment, Worsened, NoImprovement, PartiallyRecovered, FullyRecovered
   }
    struct Disease{
        string name;
        RecoveryStatus recoveryStatus;
    }
    
      enum reviewDoctor{
        Bad, Average, Good, VeryGood, Excellent  // rate 0,1,2,3,4 
    }

    mapping (address => Patient) private Patient_Record;
    mapping (address => Doctor) public Doctor_Record;
    mapping (uint256 => Medicine) public Medicine_list;
    mapping (address => reviewDoctor) public Doctors_Rating;
    mapping(address => bool) public MedRecordEditor;

    modifier onlyPatient{
        require(Patient_Record[msg.sender].exists,"Only the patient can change by ownself");
        _;
    }

    modifier onlyDoctor{
        require(Doctor_Record[msg.sender].exists,"Only Doctor can change");
        _;
    }

    modifier onlyApprovedPersons(address _patient){
        require(Patient_Record[_patient].approved_editors[msg.sender], "Unauthorized Access");
        _;
    }

    modifier _medRecordEditor(){
        require(MedRecordEditor[msg.sender]);
        _;
    }

 constructor(){
     MedRecordEditor[msg.sender] = true;
 }
    /**  
        *This function is used to register a new doctor to the ledger
        @param _name Name of the doctor
        @param _qualification Which degree he/she holds as a doctor
        @param _specialization  If the doctor is a aspecialist
        @param _workPlace Address of his/her hospital/clinic
    */
    function register_as_doctor(string memory _name, string memory _qualification, string memory _specialization,  string memory _workPlace) public {
        require(!Doctor_Record[msg.sender].exists,"Doctor's data is already associated with this address");
        Doctor_Record[msg.sender] = Doctor(_name,_qualification,_workPlace, _specialization, true);
    }

    /**
        *This function is used to register a new patient to the ledger
        @param _name Name of the user
        @param _dob Age of user
        @param _weight patient's weight in kg
        @param _height patient's height in cm
    */
    function register_as_patient(string memory _name, uint256 _dob, uint256 _weight, uint256 _height) public {
        require(!Patient_Record[msg.sender].exists,"Patient's data is already associated with this address");
        //Patient_Record[msg.sender] = Patient(_name,_dob , _weight, _height,true);
        Patient_Record[msg.sender].name = _name;
        Patient_Record[msg.sender].dateofbirth = _dob;
        Patient_Record[msg.sender].weight = _weight;
        Patient_Record[msg.sender].height = _height;
        Patient_Record[msg.sender].approved_editors[msg.sender] = true;
        Patient_Record[msg.sender].exists = true;

    }


    /**
      * approve doctor can check patient and prescribe medicines  , approved user can change patient record

    */
    function approvePatientRecordEditor(address _editor_address) public onlyPatient{
        Patient_Record[msg.sender].approved_editors[_editor_address] = true;
    }

    /*
        * Disapprove editor(Doctor or any other user) to change patient record

    */
    function disapprovePatientRecordEditor(address _editor_address) public onlyPatient{
        require(_editor_address != msg.sender);
        Patient_Record[msg.sender].approved_editors[_editor_address] = false;
    }

     /**
         @param _disease_name Name of the disease
         @param _patient address of patient (wallet address is used as unique identification)
    */
    function add_Disease(string memory _disease_name, address _patient, uint256 _treatment_status) public onlyApprovedPersons(_patient) returns(uint256 _index){
         require(_treatment_status == 0 || _treatment_status ==1, "Treatment status should be either untreated(0) or under treatment(1)");
         if(_treatment_status == 0)
         Patient_Record[_patient].disease.push(Disease(_disease_name,RecoveryStatus.NotTreated));
         else
         Patient_Record[_patient].disease.push(Disease(_disease_name,RecoveryStatus.UnderTreatment));
         return(Patient_Record[_patient].disease.length-1);
    }

    function update_Recovery_Status(address _patient, uint256 _treatment_status, uint256 _index) public onlyApprovedPersons(_patient){
        require(_treatment_status != 0 && _treatment_status < uint256(type(RecoveryStatus).max), "Invalid treatment status");
        require(_index <= Patient_Record[_patient].disease.length-1 && _index > 0,"Index error");
        Patient_Record[_patient].disease[_index].recoveryStatus = RecoveryStatus(_treatment_status);

    }

    function get_Disease_Details_Of_patient(address _patient) public view returns(Disease[] memory _d){
        _d = new Disease[](Patient_Record[_patient].disease.length);
        for(uint256 i=0;i<Patient_Record[_patient].disease.length;i++)
                _d[i] = Patient_Record[_patient].disease[i];            
    }


    /**  
        @param _id Id of the medicine
        @param _name name of the medicine
       @param _dose a recommended Dose prescribed to the patient (In general)
       @param _dosetime recommended Dose time prescribed to patient (In general)
    */
  function addMedicine(uint256 _id, string memory _name, medicine_dosage _dose, medicine_timing _dosetime) public _medRecordEditor
  {
      Medicine_list[_id] = Medicine(_name,false, _dose,_dosetime,true);
  }


/**
  @param _toPatient  prescribed to which patient
  @param _medid      medicine id
  @param _dose       prescribed dosage  
  @param _dosetime   prescribed dose timings


*/
  function prescribeMedicine(address _toPatient,uint256 _medid, medicine_dosage _dose, medicine_timing _dosetime) public onlyDoctor onlyApprovedPersons(_toPatient){
        Patient_Record[_toPatient].current_medications[msg.sender].push(Medicine_list[_medid]);
        Patient_Record[_toPatient].current_medications[msg.sender][Patient_Record[_toPatient].current_medications[msg.sender].length -1].dosage = _dose;
        Patient_Record[_toPatient].current_medications[msg.sender][Patient_Record[_toPatient].current_medications[msg.sender].length -1].dosageTiming = _dosetime;
  }

  function viewPatientDiseaseData(address _patient, uint256 _dob, string memory _pname) public view returns(Disease[] memory _d)
  {
     require(Patient_Record[_patient].dateofbirth == _dob && keccak256(abi.encodePacked(Patient_Record[_patient].name)) == keccak256(abi.encodePacked(_pname)));
     _d = Patient_Record[_patient].disease;
  }

  function viewPatientMedicationsByDoctor(address _patient, string memory _pname) public view onlyDoctor onlyApprovedPersons(_patient) returns(Medicine[] memory _m)
  {
      require(keccak256(abi.encodePacked(Patient_Record[_patient].name)) == keccak256(abi.encodePacked(_pname)));
     _m = Patient_Record[_patient].current_medications[msg.sender];
  }

  function viewMedicineDetails(uint256 _medid) public
  {

  }

  function viewPrescribedMedicines(address _patient) public onlyApprovedPersons(_patient)
  {

  }

  function viewDoctorDetails(address _doctor) public{

  }
}