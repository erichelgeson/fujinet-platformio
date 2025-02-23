#ifdef SP_OVER_SLIP

#include "Response.h"

Response::Response(const uint8_t request_sequence_number, const uint8_t status)
	: SmartPortPacket(request_sequence_number), status_(status) {}

uint8_t Response::get_status() const { return status_; }


#endif // SP_OVER_SLIP
