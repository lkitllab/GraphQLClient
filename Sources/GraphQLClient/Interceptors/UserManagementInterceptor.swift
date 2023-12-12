import Foundation
import Apollo


class UserManagementInterceptor: ApolloInterceptor {
    
    enum UserError: Error {
        case noUserLoggedIn
    }
    
    private let tokenProvider: UserTokenProvider
    
    init(tokenProvider: UserTokenProvider) {
        self.tokenProvider = tokenProvider
    }
    
    private func addTokenAndProceed<Operation: GraphQLOperation>(
        _ token: String,
        to request: HTTPRequest<Operation>,
        chain: RequestChain,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void) {
            request.addHeader(name: "Authorization", value: "Bearer \(token)")
            chain.proceedAsync(
                request: request,
                response: response,
                completion: completion
            )
    }
    
    func interceptAsync<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void) {
            guard let token = tokenProvider.authorizationToken else {
                chain.proceedAsync(
                    request: request,
                    response: response,
                    completion: completion
                )
                return
            }
            self.addTokenAndProceed(
                token,
                to: request,
                chain: chain,
                response: response,
                completion: completion
            )
    }
}
