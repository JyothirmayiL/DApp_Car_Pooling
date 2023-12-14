// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Carpooling {
    address public owner;

    // Struct to represent a user
    struct User {
        bool isRegistered;
        bool isDriver;
        bool isPassenger;
        string desiredRoute;
    }

    // Struct to represent a ride
    struct Ride {
        address driver;
        string route;
        uint seatsAvailable;
        uint pricePerSeat;
        bool isActive;
        bool isCancelled;
        mapping(address => bool) passengers;
    }

    // Mapping to store users
    mapping(address => User) public users;

    // Mapping to store rides
    mapping(uint256 => Ride) public rides;

    // Event to log ride registration
    event RideRegistered(uint256 rideId, address indexed driver, string route);

    // Event to log ride joined
    event RideJoined(uint256 rideId, address indexed passenger, uint256 seatsBooked, uint256 totalCost);

    // Event to log ride cancellation
    event RideCancelled(uint256 rideId, address indexed canceller);

    // Event to log earnings withdrawal
    event EarningsWithdrawn(address indexed driver, uint256 amount);

    // Array to store ride IDs
    uint256[] public rideIds;

    // Modifier: Ensure only the contract owner can execute certain functions
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    // Modifier: Ensure only registered users can execute certain functions
    modifier onlyRegisteredUser() {
        require(users[msg.sender].isRegistered, "User not registered");
        _;
    }

    // Modifier: Ensure only registered drivers can execute certain functions
    modifier onlyDriver() {
        require(users[msg.sender].isDriver, "User not a driver");
        _;
    }

    // Modifier: Ensure only registered passengers can execute certain functions
    modifier onlyPassenger() {
        require(users[msg.sender].isPassenger, "User not a passenger");
        _;
    }

    // Modifier: Ensure only participants of a specific ride can execute certain functions
    modifier onlyRideParticipant(uint256 _rideId) {
        Ride storage ride = rides[_rideId];
        require(
            msg.sender == ride.driver || ride.passengers[msg.sender],
            "User not a participant in the ride"
        );
        _;
    }

    // Contract constructor
    constructor() {
        owner = msg.sender;
    }

    // Function: Register as a driver
    function registerAsDriver(string memory _route, uint _seatsAvailable, uint _pricePerSeat) external onlyRegisteredUser {
        require(!users[msg.sender].isDriver, "User is already registered as a driver");

        // Update user information
        users[msg.sender] = User(true, true, false, _route);

        // Generate a unique ride ID
        uint256 rideId = uint256(keccak256(abi.encodePacked(msg.sender, block.number)));

        // Initialize a new ride
        Ride storage newRide = rides[rideId];
        newRide.driver = msg.sender;
        newRide.route = _route;
        newRide.seatsAvailable = _seatsAvailable;
        newRide.pricePerSeat = _pricePerSeat;
        newRide.isActive = false;
        newRide.isCancelled = false;
        

        // Emit event for ride registration
        emit RideRegistered(rideId, msg.sender, _route);

        // Add the rideId to the list of rideIds
        rideIds.push(rideId);
    }

    // Function: Register as a passenger
    function registerAsPassenger() external onlyRegisteredUser {
        require(!users[msg.sender].isPassenger, "User is already registered as a passenger");

        // Update user information
        users[msg.sender].isPassenger = true;
    }

    // Function: Find a carpool match for a passenger
    function findCarpoolMatch() external onlyPassenger {
        require(users[msg.sender].isPassenger, "User not a passenger");

        // Iterate through all ride IDs to find a match
        for (uint256 i = 0; i < rideIds.length; i++) {
            uint256 rideId = rideIds[i];
            Ride storage ride = rides[rideId];
            
            // Check if the ride is active, has available seats, and the route matches
            if (ride.isActive && ride.seatsAvailable > 0 && keccak256(abi.encodePacked(ride.route)) == keccak256(abi.encodePacked(users[msg.sender].desiredRoute))) {
                // Match found, call the internal logic of joinRide
                _joinRide(rideId);
                return;
            }
        }

        // No matching ride found
        revert("No matching ride found");
    }

    // Internal function: Logic for joining a ride
    function _joinRide(uint256 _rideId) internal {
        require(rides[_rideId].isActive, "Ride is not active");
        require(rides[_rideId].seatsAvailable > 0, "No available seats");
        
        uint256 seatsBooked = 1; // For simplicity, assume a passenger can book only one seat
        uint256 totalCost = seatsBooked * rides[_rideId].pricePerSeat;

        require(msg.value >= totalCost, "Insufficient funds sent");

        rides[_rideId].seatsAvailable -= seatsBooked;
        rides[_rideId].passengers[msg.sender] = true;

        // Transfer funds to the driver
        payable(rides[_rideId].driver).transfer(totalCost);

        // Emit event for ride joined
        emit RideJoined(_rideId, msg.sender, seatsBooked, totalCost);
    }

    // Function: Allow a user to join a ride
    function joinRide(uint256 _rideId) external onlyRideParticipant(_rideId) payable {
        require(rides[_rideId].isActive, "Ride is not active");
        require(rides[_rideId].seatsAvailable > 0, "No available seats");
        
        uint256 seatsBooked = 1; // For simplicity, assume a passenger can book only one seat
        uint256 totalCost = seatsBooked * rides[_rideId].pricePerSeat;

        require(msg.value >= totalCost, "Insufficient funds sent");

        rides[_rideId].seatsAvailable -= seatsBooked;
        rides[_rideId].passengers[msg.sender] = true;

        // Transfer funds to the driver
        payable(rides[_rideId].driver).transfer(totalCost);

        // Emit event for ride joined
        emit RideJoined(_rideId, msg.sender, seatsBooked, totalCost);
    }

    // Function: Withdraw earnings for a driver
    function withdrawEarnings() external onlyDriver {
        // Implementation for withdrawing earnings goes here
        // This function should transfer the driver's earnings to their address.
        // For simplicity, this is left as a placeholder.
        
        // Placeholder: Transfer the balance to the driver
        payable(msg.sender).transfer(address(this).balance);

        // Emit event for earnings withdrawn
        emit EarningsWithdrawn(msg.sender, address(this).balance);
    }

    // Function: Cancel a ride
    function cancelRide(uint256 _rideId) external onlyRideParticipant(_rideId) {
        require(!rides[_rideId].isCancelled, "Ride is already cancelled");
        
        // Refund passengers if ride is cancelled
        if (msg.sender == rides[_rideId].driver) {
            // If the driver cancels, refund passengers
            refundPassengers(_rideId);
        }

        rides[_rideId].isCancelled = true;

        // Emit event for ride cancelled
        emit RideCancelled(_rideId, msg.sender);
    }

    // Function: Get details of a specific ride
    function getRideDetails(uint256 _rideId) external view returns (
        address driver,
        string memory route,
        uint seatsAvailable,
        uint pricePerSeat,
        bool isActive,
        bool isCancelled
    ) {
        Ride storage ride = rides[_rideId];
        return (ride.driver, ride.route, ride.seatsAvailable, ride.pricePerSeat, ride.isActive, ride.isCancelled);
    }

    // Internal function: Refund passengers if a ride is cancelled
    function refundPassengers(uint256 _rideId) internal {
        for (uint256 i = 0; i < rides[_rideId].seatsAvailable; i++) {
            address passenger = getNthPassenger(_rideId, i);
            if (passenger != address(0)) {
                uint256 refundAmount = rides[_rideId].pricePerSeat;
                payable(passenger).transfer(refundAmount);
            }
        }
    }

    // Internal function: Get the nth passenger of a ride
    function getNthPassenger(uint256 _rideId, uint256 n) internal view returns (address) {
        uint256 count = 0;
        for (uint256 i = 0; i < rides[_rideId].seatsAvailable; i++) {
            if (rides[_rideId].passengers[getPassengerAtIndex(_rideId, i)]) {
                if (count == n) {
                    return getPassengerAtIndex(_rideId, i);
                }
                count++;
            }
        }
        return address(0);
    }

    // Internal function: Get the passenger at a specific index of a ride
    function getPassengerAtIndex(uint256 _rideId, uint256 index) internal view returns (address) {
        require(index < rides[_rideId].seatsAvailable, "Index out of bounds");
        
        // Logic to get the passenger address based on the index
        // This could be a more complex logic depending on use case
        // For simplicity, assuming the passenger address is just the user's address.
        return getNthPassenger(_rideId, index);
    }
}
