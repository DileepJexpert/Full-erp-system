export interface OtpSendResponse {
  success: boolean;
  message: string;
}

export interface AuthTokenResponse {
  token: string;
  user: {
    id: string;
    name: string;
    phone: string;
    role: string;
    businessId: string;
    businessName: string;
    businessType: string;
  };
}

export interface BusinessRegistrationResponse {
  token: string;
  business: {
    id: string;
    name: string;
    type: string;
  };
  user: {
    id: string;
    name: string;
    phone: string;
    role: string;
  };
}
