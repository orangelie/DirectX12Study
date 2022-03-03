#include "FrameResource.h"

namespace Mawi1e {
	FrameResource::FrameResource(ID3D12Device* Device, UINT passCount, UINT objCount) {
		Device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,
			IID_PPV_ARGS(m_CommandAllocator.GetAddressOf()));

		m_ObjCB = std::make_unique<UploadBuffer<ObjConstants>>(Device, objCount, true);
		m_PassCB = std::make_unique<UploadBuffer<PassConstants>>(Device, passCount, true);
	}

	FrameResource::~FrameResource() {
	}
}