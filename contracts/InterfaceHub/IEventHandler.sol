// SPDX-License-Identifier: MIT

pragma solidity =0.8.21;

interface IEventHandler {

    function setWiseLending(
        address _wiseLending
    )
        external;

    function emitEvent(
        uint8 _eventId,
        bytes calldata _eventData
    )
        external;
}