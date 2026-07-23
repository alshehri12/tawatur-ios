// AuthViewModel.swift — Shared ViewModel for phone + OTP + registration flows.

import Foundation
import Combine
import SwiftUI

enum AuthPurpose {
    case login, register
    var apiPurpose: String { self == .login ? "login" : "register" }
}

final class AuthViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var otpSent = false
    @Published var otpDebug: String?

    @Published var otpCode = ""

    @MainActor
    func requestOTP(phone: String, purpose: AuthPurpose) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .requestOTP(phone: phone, purpose: purpose.apiPurpose),
                as: OTPResponse.self
            )
            otpSent    = true
            otpDebug   = response.otp
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func login(phone: String, otp: String, authState: AuthState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .login(phone: phone, otp: otp),
                as: AuthResponse.self
            )
            authState.handleAuthResponse(response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func registerIndividual(phone: String, otp: String, fullName: String,
                             nationalId: String?, iqama: String?,
                             authState: AuthState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .registerIndividual(phone: phone, otp: otp, fullName: fullName,
                                    nationalId: nationalId?.isEmpty == false ? nationalId : nil,
                                    iqama: iqama?.isEmpty == false ? iqama : nil),
                as: AuthResponse.self
            )
            authState.handleAuthResponse(response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func registerBusiness(phone: String, otp: String,
                           crNumber: String, businessName: String,
                           authState: AuthState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .registerBusiness(phone: phone, otp: otp,
                                  crNumber: crNumber, businessName: businessName),
                as: AuthResponse.self
            )
            authState.handleAuthResponse(response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
