/*
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import LoggerAPI
import KituraSys
import CCurl
import Socket

import Foundation

// MARK: ClientRequest

public class ClientRequest {

    /// Initialize the one time initialization struct to cause one time initializations to occur
    static private let oneTime = OneTimeInitializations()
    
    public var headers = [String: String]()

    // MARK: -- Private
    
    /// URL used for the request
    public private(set) var url: String = ""
    
    /// HTTP method (GET, POST, PUT, DELETE) for the request
    public private(set) var method: String = "get"
    
    /// Username if using Basic Auth
    public private(set) var userName: String?
    
    /// Password if using Basic Auth
    public private(set) var password: String?

    /// Maximum number of redirects before failure
    public private(set) var maxRedirects = 10
    
    /// Adds the "Connection: close" header
    public private(set) var closeConnection = false

    /// Handle for working with libCurl
    private var handle: UnsafeMutableRawPointer?
    
    /// List of header information
    private var headersList: UnsafeMutablePointer<curl_slist>?
    
    /// BufferList to store bytes to be written
    fileprivate var writeBuffers = BufferList()

    /// Response instance for communicating with client
    fileprivate var response = ClientResponse()
    
    /// The callback to receive the response
    private var callback: Callback
    
    /// Should SSL verification be disabled
    private var disableSSLVerification = false
    
    /// Client request option values
    public enum Options {
        
        case method(String), schema(String), hostname(String), port(Int16), path(String),
        headers([String: String]), username(String), password(String), maxRedirects(Int), disableSSLVerification
        
    }
    
    /// Response callback closure type
    public typealias Callback = (ClientResponse?) -> Void

    /// Initializes a ClientRequest instance
    ///
    /// - Parameter url: url for the request 
    /// - Parameter callback:
    ///
    /// - Returns: a ClientRequest instance
    init(url: String, callback: @escaping Callback) {
        
        self.url = url
        self.callback = callback
        
    }

    /// Initializes a ClientRequest instance
    ///
    /// - Parameter options: a list of options describing the request
    /// - Parameter callback:
    ///
    /// - Returns: a ClientRequest instance
    init(options: [Options], callback: @escaping Callback) {

        self.callback = callback

        var theSchema = "http://"
        var hostName = "localhost"
        var path = ""
        var port = ""

        for option in options  {
            switch(option) {

                case .method, .headers, .maxRedirects, .disableSSLVerification:
                    // call set() for Options that do not construct the URL
                    set(option)
                case .schema(var schema):
                    if !schema.contains("://") && !schema.isEmpty {
                      schema += "://"
                    }
                    theSchema = schema
                case .hostname(let host):
                    hostName = host
                case .port(let thePort):
                    port = ":\(thePort)"
                case .path(var thePath):
                    if thePath.characters.first != "/" {
                      thePath = "/" + thePath
                    }
                    path = thePath
                case .username(let userName):
                    self.userName = userName
                case .password(let password):
                    self.password = password
            }
        }

        // Adding support for Basic HTTP authentication
        let user = self.userName ?? ""
        let pwd = self.password ?? ""
        var authenticationClause = ""
        // If either the userName or password are non-empty, add the authenticationClause
        if (!user.isEmpty || !pwd.isEmpty) {
          authenticationClause = "\(user):\(pwd)@"
        }

        url = "\(theSchema)\(authenticationClause)\(hostName)\(port)\(path)"

    }

    /// Set a single option in the request.  URL parameters must be set in init()
    ///
    /// - Parameter option: an option describing the request
    public func set(_ option: Options) {

        switch(option) {
        case .schema, .hostname, .port, .path, .username, .password:
            Log.error("Must use ClientRequest.init() to set URL components")
        case .method(let method):
            self.method = method
        case .headers(let headers):
            for (key, value) in headers {
                self.headers[key] = value
            }
        case .maxRedirects(let maxRedirects):
            self.maxRedirects = maxRedirects
        case .disableSSLVerification:
            self.disableSSLVerification = true
        }
    }

    /// Parse an URL String into options
    ///
    /// - Parameter urlString: URL of a String type
    ///
    /// - Returns: a ClientRequest.Options array
    public class func parse(_ urlString: String) -> [ClientRequest.Options] {

        if let url = URL(string: urlString) {
            return parse(url)
        }
        return []
    }

    /// Parse an URL class into options
    ///
    /// - Parameter url: Foundation URL class
    ///
    /// - Returns: a ClientRequest.Options array
    public class func parse(_ url: URL) -> [ClientRequest.Options] {

        var options: [ClientRequest.Options] = []

        if let scheme = url.scheme {
            options.append(.schema("\(scheme)://"))
        }
        if let host = url.host {
            options.append(.hostname(host))
        }
        var fullPath = url.path
        // query strings and parameters need to be appended here
        if let query = url.query {
            fullPath += "?"
            fullPath += query
        }
        options.append(.path(fullPath))
        if let port = url.port {
            options.append(.port(Int16(port)))
        }
        if let username = url.user {
            options.append(.username(username))
        }
        if let password = url.password {
            options.append(.password(password))
        }
        return options
    }

    /// Instance destruction
    deinit {

        if  let handle = handle  {
            curl_easy_cleanup(handle)
        }

        if  headersList != nil  {
            curl_slist_free_all(headersList)
        }

    }

    /// Writes a string to the response
    ///
    /// - Parameter from: String to be written
    public func write(from string: String) {
        
        if  let data = StringUtils.toUtf8String(string)  {
            write(from: data)
        }
        
    }

    /// Writes data to the response
    ///
    /// - Parameter from: NSData to be written
    public func write(from data: Data) {
        
        writeBuffers.append(data: data)
        
    }

    /// End servicing the request, send response back
    ///
    /// - Parameter data: string to send before ending
    /// - Parameter close: add the "Connection: close" header
    public func end(_ data: String, close: Bool = false) {
        
        write(from: data)
        end(close: close)
        
    }

    /// End servicing the request, send response back
    ///
    /// - Parameter data: data to send before ending
    /// - Parameter close: add the "Connection: close" header
    public func end(_ data: Data, close: Bool = false) {
        
        write(from: data)
        end(close: close)
        
    }

    /// End servicing the request, send response back
    ///
    /// - Parameter close: add the "Connection: close" header
    public func end(close: Bool = false) {

        closeConnection = close

        guard  let urlBuffer = StringUtils.toNullTerminatedUtf8String(url) else {
            callback(nil)
            return
        }
        
        prepareHandle(using: urlBuffer)

        let invoker = CurlInvoker(handle: handle!, maxRedirects: maxRedirects)
        invoker.delegate = self

        var code = invoker.invoke()
        guard code == CURLE_OK else {
            Log.error("ClientRequest Error, Failed to invoke HTTP request. CURL Return code=\(code)")
            callback(nil)
            return
        }
        
        code = curlHelperGetInfoLong(handle!, CURLINFO_RESPONSE_CODE, &response.status)
        guard code == CURLE_OK else {
            Log.error("ClientRequest Error. Failed to get response code. CURL Return code=\(code)")
            callback(nil)
            return
        }
        
        let parseStatus = response.parse()
        guard  parseStatus.error == nil else {
            Log.error("ClientRequest error. Failed to parse response. status=\(parseStatus.error!)")
            callback(nil)
            return
        }

        self.callback(self.response)
    }

    /// Prepare the handle 
    ///
    /// Parameter using: The URL to use when preparing the handle
    private func prepareHandle(using urlBuffer: Data) {
        
        handle = curl_easy_init()
        // HTTP parser does the decoding
        curlHelperSetOptInt(handle!, CURLOPT_HTTP_TRANSFER_DECODING, 0)
        _ = urlBuffer.withUnsafeBytes() { [unowned self] (bytes: UnsafePointer<Int8>) in
            curlHelperSetOptString(self.handle!, CURLOPT_URL, bytes)
        }
        if disableSSLVerification {
            curlHelperSetOptInt(handle!, CURLOPT_SSL_VERIFYHOST, 0)
            curlHelperSetOptInt(handle!, CURLOPT_SSL_VERIFYPEER, 0)
        }
        setMethod()
        let count = writeBuffers.count
        curlHelperSetOptInt(handle!, CURLOPT_POSTFIELDSIZE, count)
        setupHeaders()
        curlHelperSetOptString(handle!, CURLOPT_COOKIEFILE, "")

        // To see the messages sent by libCurl, uncomment the next line of code
        //curlHelperSetOptInt(handle, CURLOPT_VERBOSE, 1)
    }

    /// Sets the HTTP method in libCurl to the one specified in method
    private func setMethod() {

        let methodUpperCase = method.uppercased()
        switch(methodUpperCase) {
            case "GET":
                curlHelperSetOptBool(handle!, CURLOPT_HTTPGET, CURL_TRUE)
            case "POST":
                curlHelperSetOptBool(handle!, CURLOPT_POST, CURL_TRUE)
            case "PUT":
                curlHelperSetOptBool(handle!, CURLOPT_PUT, CURL_TRUE)
            case "HEAD":
                curlHelperSetOptBool(handle!, CURLOPT_NOBODY, CURL_TRUE)
            default:
                curlHelperSetOptString(handle!, CURLOPT_CUSTOMREQUEST, methodUpperCase)
        }

    }

    /// Sets the headers in libCurl to the ones in headers
    private func setupHeaders() {

        if closeConnection {
            headers["Connection"] = "close"
        }
        
        for (headerKey, headerValue) in headers {
            let headerString = StringUtils.toNullTerminatedUtf8String("\(headerKey): \(headerValue)")
            if  let headerString = headerString  {
                headerString.withUnsafeBytes() { (headerUTF8: UnsafePointer<Int8>) in
                    headersList = curl_slist_append(headersList, headerUTF8)
                }
            }
        }
        curlHelperSetOptList(handle!, CURLOPT_HTTPHEADER, headersList)
    }

}

// MARK: CurlInvokerDelegate extension
extension ClientRequest: CurlInvokerDelegate {
    
    /// libCurl callback to recieve data sent by the server
    fileprivate func curlWriteCallback(_ buf: UnsafeMutablePointer<Int8>, size: Int) -> Int {
        
        response.responseBuffers.append(bytes: UnsafeRawPointer(buf).assumingMemoryBound(to: UInt8.self), length: size)
        return size
        
    }

    /// libCurl callback to provide the data to send to the server
    fileprivate func curlReadCallback(_ buf: UnsafeMutablePointer<Int8>, size: Int) -> Int {
        
        let count = writeBuffers.fill(buffer: UnsafeMutableRawPointer(buf).assumingMemoryBound(to: UInt8.self), length: size)
        return count
        
    }

    /// libCurl callback invoked when a redirect is about to be done
    fileprivate func prepareForRedirect() {
        
        response.responseBuffers.reset()
        writeBuffers.rewind()
        
    }
}

/// Helper class for invoking commands through libCurl
private class CurlInvoker {
    
    /// Pointer to the libCurl handle
    private var handle: UnsafeMutableRawPointer
    
    /// Delegate that can have a read or write callback
    fileprivate weak var delegate: CurlInvokerDelegate?
    
    /// Maximum number of redirects
    private let maxRedirects: Int

    /// Initializes a new CurlInvoker instance
    fileprivate init(handle: UnsafeMutableRawPointer, maxRedirects: Int) {
        
        self.handle = handle
        self.maxRedirects = maxRedirects
        
    }

    /// Run the HTTP method through the libCurl library
    ///
    /// - Returns: a status code for the success of the operation
    fileprivate func invoke() -> CURLcode {

        var rc: CURLcode = CURLE_FAILED_INIT
        if delegate == nil {
            return rc
        }

        withUnsafeMutablePointer(to: &delegate) {ptr in
            self.prepareHandle(ptr)

            var redirected = false
            var redirectCount = 0
            repeat {
                rc = curl_easy_perform(handle)

                if  rc == CURLE_OK  {
                    var redirectUrl: UnsafeMutablePointer<Int8>? = nil
                    let infoRc = curlHelperGetInfoCString(handle, CURLINFO_REDIRECT_URL, &redirectUrl)
                    if  infoRc == CURLE_OK {
                        if  redirectUrl != nil  {
                            curlHelperSetOptString(handle, CURLOPT_URL, redirectUrl)
                            redirected = true
                            delegate?.prepareForRedirect()
                            redirectCount+=1
                        }
                        else {
                            redirected = false
                        }
                    }
                }

            } while  rc == CURLE_OK  &&  redirected  &&  redirectCount < maxRedirects
        }

        return rc
    }

    /// Prepare the handle
    ///
    /// - Parameter ptr: pointer to the CurlInvokerDelegat
    private func prepareHandle(_ ptr: UnsafeMutablePointer<CurlInvokerDelegate?>) {

        curlHelperSetOptReadFunc(handle, ptr) { (buf: UnsafeMutablePointer<Int8>?, size: Int, nMemb: Int, privateData: UnsafeMutableRawPointer?) -> Int in

                let p = privateData?.assumingMemoryBound(to: CurlInvokerDelegate.self).pointee
                return (p?.curlReadCallback(buf!, size: size*nMemb))!
        }

        curlHelperSetOptWriteFunc(handle, ptr) { (buf: UnsafeMutablePointer<Int8>?, size: Int, nMemb: Int, privateData: UnsafeMutableRawPointer?) -> Int in

                let p = privateData?.assumingMemoryBound(to: CurlInvokerDelegate.self).pointee
                return (p?.curlWriteCallback(buf!, size: size*nMemb))!
        }
    }
    
}


/// Delegate protocol for objects operated by CurlInvoker
private protocol CurlInvokerDelegate: class {
    
    func curlWriteCallback(_ buf: UnsafeMutablePointer<Int8>, size: Int) -> Int
    func curlReadCallback(_ buf: UnsafeMutablePointer<Int8>, size: Int) -> Int
    func prepareForRedirect()
    
}


/// Singleton struct for one time initializations
private struct OneTimeInitializations {

    init() {
        curl_global_init(Int(CURL_GLOBAL_SSL))
    }
}

