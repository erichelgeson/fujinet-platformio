#pragma once

#ifdef BUILD_APPLE
#ifdef SP_OVER_SLIP

#include "connector.h"
#include "COMConnection.h"
#include <string>

class connector_com : public connector
{
public:
	virtual std::shared_ptr<Connection> create_connection() override;
};

#endif
#endif
