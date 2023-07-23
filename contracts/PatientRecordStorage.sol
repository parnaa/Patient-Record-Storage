//SPDX-License-Identifier: unlicensed
pragma solidity ^0.8.18;

contract patientRecordStorage{     
   
    /// Doctor struct stores Doctor's Details
    /// reviewers store total number reviewers, everytime someone give review , reviewers increment by 1 
    /// Total rating point is the sum of all rating accumulated by the doctor
    struct Doctor{
        string name;
        string qualification;
        string workPlace;
        string specialization;
        uint256 reviewers;
        uint256 totalRatingPoints;
        bool exists;
    }

    /// dosage of medicine: Once, twice, thrice, SoS
    enum medicine_dosage{
        OD, BD, TDS, SOS //0: OD, 1: BD, 2: TDS, 3: SOS
    }

    /// Medicine Timing before meal or after meal
    enum medicine_timing{
        Before_Meal, After_Meal //0:Before_Meal, 1: After_Meal
    }

    /// Generic Medicine Details with recommended dosage and timings
    struct Medicine{
        string name;
        bool continue_status;
        medicine_dosage dosage;
        medicine_timing dosageTiming;
        bool exists;
    }
    
    /// Patient structure to store patient's data
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

   /// Disease Details with recoverystatus
    struct Disease{
        string name;
        RecoveryStatus recoveryStatus;
    }
    

      enum reviewDoctor{
        Bad, Average, Good, VeryGood, Excellent  // rate 0,1,2,3,4 
    }

    mapping (address => Patient) private Patient_Record; //Patient_Record: key is patient's address and value is Patient structur
    mapping (address => Doctor) public Doctor_Record; //Doctor_Record: key is doctor's address and value is Doctor structure
    mapping (uint256 => Medicine) public Medicine_list; //Medicine_list: key is medicine id and value is Medicine Structure
    mapping (address => mapping(address => reviewDoctor)) public Doctors_Rating; //Doctors_Rating: key is doctor's address and value is another mapping with key Patient's address with value reviewDoctor rating(0-4)
    mapping(address => bool) public MedRecordEditor; //MedRecordEditor: key is User's address and value is true/false 

    /// onlyPatient modifier will be used with functions which only a patient himself can execute
    modifier onlyPatient{
        require(Patient_Record[msg.sender].exists,"Only the patient can change by ownself");
        _;
    }

    ///onlyDoctor modifier will be used with functions, which only a doctor can execute    
    modifier onlyDoctor{
        require(Doctor_Record[msg.sender].exists,"Only Doctor can change");
        _;
    }

    /// onlyApprovedPersons are the addresses who are approved by a patient to edit his record, 
    /// This modifier will be used where Patient and approved persons like the doctor who is checking the patient currently can modify patient data
    modifier onlyApprovedPersons(address _patient){
        require(Patient_Record[_patient].approved_editors[msg.sender], "Unauthorized Access");
        _;
    }
 
    /// medicine recored can be added to medicines by only medrecordeditor
    /// by default contract owner is medrecordeditor and owner can add more editors
    modifier _medRecordEditor(){
        require(MedRecordEditor[msg.sender]);
        _;
    }

    // Contract owner by default can add Medicines to medicine list as approved as MedrecordEditor
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
        Doctor_Record[msg.sender] = Doctor(_name,_qualification,_workPlace, _specialization, 0, 0,true);
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
      @param _editor_address address to be approved as Patiend Record Editor  
    */
    function approvePatientRecordEditor(address _editor_address) public onlyPatient{
        Patient_Record[msg.sender].approved_editors[_editor_address] = true;
    }

    /*
        * Disapprove editor(Doctor or any other user) to change patient record
        @param _editor_address patient record editor address

    */
    function disapprovePatientRecordEditor(address _editor_address) public onlyPatient{
        require(_editor_address != msg.sender);
        Patient_Record[msg.sender].approved_editors[_editor_address] = false;
    }

     /**
         @param _disease_name Name of the disease
         @param _patient address of patient (wallet address is used as unique identification)
         @param _treatment_status patient's recovery or treat status like under treatment
    */
    function add_Disease(string memory _disease_name, address _patient, uint256 _treatment_status) public onlyApprovedPersons(_patient) returns(uint256 _index){
         require(_treatment_status == 0 || _treatment_status ==1, "Treatment status should be either untreated(0) or under treatment(1)");
         if(_treatment_status == 0)
         Patient_Record[_patient].disease.push(Disease(_disease_name,RecoveryStatus.NotTreated));
         else
         Patient_Record[_patient].disease.push(Disease(_disease_name,RecoveryStatus.UnderTreatment));
         return(Patient_Record[_patient].disease.length-1);
    }

     /**
         
         @param _patient address of patient (wallet address is used as unique identification)
         @param _treatment_status patient's recovery or treat status like under treatment
         @param _index disease array index of a particular disease in patient record
    */
    function update_Recovery_Status(address _patient, uint256 _treatment_status, uint256 _index) public onlyApprovedPersons(_patient){
        require(_treatment_status != 0 && _treatment_status < uint256(type(RecoveryStatus).max), "Invalid treatment status");
        require(_index <= Patient_Record[_patient].disease.length-1 && _index > 0,"Index error");
        Patient_Record[_patient].disease[_index].recoveryStatus = RecoveryStatus(_treatment_status);

    }

    /**
        @param _patient patient's wallet address
        @return _d the disease array of Patient_record[<patient's addess>]
    */

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

/**
    @param _doctor doctor's wallet address
    @param _rate review point/rating point (input must be in between 0 and 4)

*/

  function giveReviewTotheDoctor(address _doctor, uint256 _rate) public onlyPatient{
      require(Patient_Record[msg.sender].approved_editors[_doctor] && Patient_Record[msg.sender].current_medications[_doctor][0].exists);
      require(_rate < 5);
      Doctor_Record[_doctor].totalRatingPoints +=  _rate;
      Doctor_Record[_doctor].reviewers++;
      Doctors_Rating[_doctor][msg.sender] = reviewDoctor(_rate);
  }

/**
  *
  @param _patient patient's wallet address
  @param _dob patient's date of bith in timestamp
  @param _pname patient's name
  @return _d Disease array

*/
  function viewPatientDiseaseDetails(address _patient, uint256 _dob, string memory _pname) public view returns(Disease[] memory _d)
  {
     require(Patient_Record[_patient].dateofbirth == _dob && keccak256(abi.encodePacked(Patient_Record[_patient].name)) == keccak256(abi.encodePacked(_pname)));
     _d = Patient_Record[_patient].disease;
  }

/**
  *
  @param _patient patient's wallet address
  @param _pname patient's name
  @return _m    array of Medicine

*/
  function viewPatientMedicationsByDoctor(address _patient, string memory _pname) public view onlyDoctor onlyApprovedPersons(_patient) returns(Medicine[] memory _m)
  {
      require(keccak256(abi.encodePacked(Patient_Record[_patient].name)) == keccak256(abi.encodePacked(_pname)));
     _m = Patient_Record[_patient].current_medications[msg.sender];
  }

/**
    @param _medid  Medicine Id
    @return _m Medicine List array

*/
  function viewMedicineDetails(uint256 _medid) public view returns(Medicine memory _m)
  {
     _m = Medicine_list[_medid];
  }

/**
    *
    @param _doctor Doctor's wallet address
    @return _doc Doctor's details from Doctor structure

*/
   function viewDoctorDetails(address _doctor) public view returns (Doctor memory _doc){
   _doc = Doctor_Record[_doctor];
  }

/**
    @param _doctor  Doctor's wallet address
    @return reviewDoctor 
*/
   function viewDoctorRating(address _doctor) public view returns(reviewDoctor){
       require(Doctor_Record[_doctor].reviewers > 0,"No reviews yet");
       return reviewDoctor(uint256(Doctor_Record[_doctor].totalRatingPoints)/Doctor_Record[_doctor].reviewers);
   }
}
