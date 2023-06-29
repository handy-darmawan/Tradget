//
//  ProfileRepository.swift
//  sogmc3
//
//  Created by Dimas on 23/06/23.
//

import Foundation
import CoreData

struct ProfileRemoteDataSourceMock: ProfileRemoteDataSourceProtocol {
    func getPublicAccessToken() async -> Result<AuthResponse, RequestError> {
        return .success(AuthResponse(status: 200, message: "ok", data: AuthResponse.Data(accessToken: "accessTokenMock")))
    }
    
    func getUserAuthTokens(for userID: String) async -> Result<AccessTokenResponse, RequestError> {
        return .success(AccessTokenResponse(accessTokens: [
            AccessToken(accessToken: "mock-access-token-1", bankId: "1"),
            AccessToken(accessToken: "mock-access-token-2", bankId: "2")
        ]))
    }
}

struct ProfileRepository {
    
    let profileLocalDataSource = ProfileLocalDataSource()
    let profileRemoteDataSource = ProfileRemoteDataSource()
    
    init() {
//        self.profileLocalDataSource = ProfileLocalDataSource()
//        self.profileRemoteDataSource = ProfileRemoteDataSource()
        
//        #if DEBUG
//        profileRemoteDataSource = ProfileRemoteDataSourceMock()
//        #else
//        profileRemoteDataSource = ProfileRemoteDataSource()
//        #endif
    }
    
    func fetchPublicAcessToken() async throws {
        let fetchResult = await profileRemoteDataSource.getPublicAccessToken()
        
        let publicAccessToken: String?
        switch fetchResult {
        case .success(let response):
            publicAccessToken = response.data.accessToken
        case .failure(let failure):
            throw failure
        }
        
        guard let publicAccessToken else { throw RequestError.invalidAuthString }
        
        try profileLocalDataSource.savePublicAccessToken(publicAccessToken)
    }
    
    func readPublicAccessToken() throws -> String {
        try profileLocalDataSource.readPublicAccessToken()
    }
    
    /// Fetch user access tokens and save it to the keychain
    @discardableResult
    func fetchUserAccessToken(for userID: String) async throws -> [String] {
        let result = await profileRemoteDataSource.getAllUserTokens(for: "123")
        let tokens: [UserAccessTokenResponse]
        switch result {
        case .success(let success):
            tokens = success
        case .failure(let failure):
            throw failure
        }
        
        try profileLocalDataSource.saveAccessTokens(tokens)
        
        return tokens.map { $0.accessToken }
    }
    
    @discardableResult
    func readAccessTokens() throws -> [String] {
        try profileLocalDataSource.readAccessToken()
    }
    
    func fetchAndSaveTokens() async {
        let context = CoreDataManager.instance.context
        
        do {
            let transactions = try await TransactionRepository().fetchTransactions()
            
            for transaction in transactions {
                
                let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
                request.predicate = NSPredicate(format: "referenceID = %@", argumentArray: [transaction.referenceId])
                
                if let object = try context.fetch(request).first {
                    // if a transaction with a given reference id is already exist, continue
                    continue
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                guard let date = dateFormatter.date(from: transaction.date) else {
                    print("error while creating date from string: \(transaction.date)")
                    continue
                }
                
                let newTransactionEntity = TransactionEntity(context: context)
                newTransactionEntity.referenceID = transaction.referenceId
                newTransactionEntity.transactionAmount = Int64(transaction.amount)
                newTransactionEntity.transactionDate = date
                newTransactionEntity.transactionaName = transaction.description
                
                let newSubcatory = SubCategoryEntity(context: context)
                newSubcatory.subCategoryName = transaction.category.categoryName.capitalized
                newTransactionEntity.subcategories = newSubcatory
                
                try context.save()
            }
            
        } catch {
            print("error:", error )
        }
    }
    
    func readTransactions() async -> [TransactionEntity] {
        let context = CoreDataManager.instance.context
        
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        let result = try! context.fetch(request)
        
        return result
    }
    
//    func fetchUserAccessToken(for userID: String) async throws {
//        let result = await profileRemoteDataSource.getUserAuthTokens(for: userID)
//        switch result {
//        case .success(let success):
//            let userAccessTokens = success.accessTokens
//            for accessToken in userAccessTokens {
//                try profileLocalDataSource.saveUserAccessToken(accessToken.accessToken, forBankID: accessToken.bankId)
//                print("\(accessToken) saved")
//            }
//        case .failure(let failure):
//            throw failure
//        }
//    }
    
}
