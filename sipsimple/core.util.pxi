# Copyright (C) 2008-2009 AG Projects. See LICENSE for details.
#

# python imports

import re

# classes

cdef class PJSTR:
    cdef pj_str_t pj_str
    cdef object str

    def __cinit__(self, str):
        self.str = str
        _str_to_pj_str(str, &self.pj_str)

    def __str__(self):
        return self.str


cdef class SIPStatusMessages:
    cdef object _default_status

    def __cinit__(self, *args, **kwargs):
        self._default_status = _pj_str_to_str(pjsip_get_status_text(0)[0])

    def __getitem__(self, int val):
        cdef object _status
        _status = _pj_str_to_str(pjsip_get_status_text(val)[0])
        if _status == self._default_status:
            raise IndexError("Unknown SIP response code: %d" % val)
        return _status


cdef class frozenlist:
    cdef int initialized
    cdef list list
    cdef long hash
    def __cinit__(self, *args, **kw):
        self.list = list()
        self.initialized = 0
        self.hash = 0
    def __init__(self, *args, **kw):
        if not self.initialized:
            self.list = list(*args, **kw)
            self.initialized = 1
            self.hash = hash(tuple(self.list))
    def __repr__(self):
        return "frozenlist(%r)" % self.list
    def __len__(self):
        return self.list.__len__()
    def __hash__(self):
        return self.hash
    def __iter__(self):
        return self.list.__iter__()
    def __cmp__(self, frozenlist other):
        return self.list.__cmp__(other.list)
    def __richcmp__(frozenlist self, other, op):
        if isinstance(other, frozenlist):
            other = (<frozenlist>other).list
        if op == 0:
            return self.list.__cmp__(other) < 0
        elif op == 1:
            return self.list.__cmp__(other) <= 0
        elif op == 2:
            return self.list.__eq__(other) 
        elif op == 3:
            return self.list.__ne__(other) 
        elif op == 4:
            return self.list.__cmp__(other) > 0
        elif op == 5:
            return self.list.__cmp__(other) >= 0
        else:
            return NotImplemented
    def __contains__(self, item):
        return self.list.__contains__(item)
    def __getitem__(self, key):
        return self.list.__getitem__(key)
    def __getslice__(self, i, j):
        return self.list.__getslice__(i, j)
    def __add__(first, second):
        if isinstance(first, frozenlist):
            first = (<frozenlist>first).list
        if isinstance(second, frozenlist):
            second = (<frozenlist>second).list
        return frozenlist(first+second)
    def __mul__(first, second):
        if isinstance(first, frozenlist):
            first = (<frozenlist>first).list
        if isinstance(second, frozenlist):
            second = (<frozenlist>second).list
        return frozenlist(first*second)
    def __reversed__(self):
        return self.list.__reversed__()
    def count(self, elem):
        return self.list.count(elem)
    def index(self, elem):
        return self.list.index(elem)


cdef class frozendict:
    cdef int initialized
    cdef dict dict
    cdef long hash
    def __cinit__(self, *args, **kw):
        self.dict = dict()
        self.initialized = 0
    def __init__(self, *args, **kw):
        if not self.initialized:
            self.dict = dict(*args, **kw)
            self.initialized = 1
            self.hash = hash(tuple(self.dict.iteritems()))
    def __repr__(self):
        return "frozendict(%r)" % self.dict
    def __len__(self):
        return self.dict.__len__()
    def __hash__(self):
        return self.hash
    def __iter__(self):
        return self.dict.__iter__()
    def __cmp__(self, frozendict other):
        return self.dict.__cmp__(other.dict)
    def __richcmp__(frozendict self, other, op):
        if isinstance(other, frozendict):
            other = (<frozendict>other).dict
        if op == 0:
            return self.dict.__cmp__(other) < 0
        elif op == 1:
            return self.dict.__cmp__(other) <= 0
        elif op == 2:
            return self.dict.__eq__(other) 
        elif op == 3:
            return self.dict.__ne__(other) 
        elif op == 4:
            return self.dict.__cmp__(other) > 0
        elif op == 5:
            return self.dict.__cmp__(other) >= 0
        else:
            return NotImplemented
    def __contains__(self, item):
        return self.dict.__contains__(item)
    def __getitem__(self, key):
        return self.dict.__getitem__(key)
    def copy(self):
        return self
    def get(self, *args):
        return self.dict.get(*args)
    def has_key(self, key):
        return self.dict.has_key(key)
    def items(self):
        return self.dict.items()
    def iteritems(self):
        return self.dict.iteritems()
    def iterkeys(self):
        return self.dict.iterkeys()
    def itervalues(self):
        return self.dict.itervalues()
    def keys(self):
        return self.dict.keys()
    def values(self):
        return self.dict.values()


# functions

cdef int _str_to_pj_str(object string, pj_str_t *pj_str) except -1:
    pj_str.ptr = PyString_AsString(string)
    pj_str.slen = len(string)

cdef object _pj_str_to_str(pj_str_t pj_str):
    return PyString_FromStringAndSize(pj_str.ptr, pj_str.slen)

cdef object _pj_status_to_str(int status):
    cdef char buf[PJ_ERR_MSG_SIZE]
    return _pj_str_to_str(pj_strerror(status, buf, PJ_ERR_MSG_SIZE))

cdef object _pj_status_to_def(int status):
    return _re_pj_status_str_def.match(_pj_status_to_str(status)).group(1)

cdef dict _pjsip_param_to_dict(pjsip_param *param_list):
    cdef pjsip_param *param
    cdef dict retval = dict()
    param = <pjsip_param *> (<pj_list *> param_list).next
    while param != param_list:
        if param.value.slen == 0:
            retval[_pj_str_to_str(param.name)] = None
        else:
            retval[_pj_str_to_str(param.name)] = _pj_str_to_str(param.value)
        param = <pjsip_param *> (<pj_list *> param).next
    return retval

cdef int _dict_to_pjsip_param(dict params, pjsip_param *param_list, pj_pool_t *pool):
    cdef pjsip_param *param = NULL
    for name, value in params.iteritems():
        param = <pjsip_param *> pj_pool_alloc(pool, sizeof(pjsip_param))
        if param == NULL:
            return -1
        _str_to_pj_str(name, &param.name)
        if value is None:
            param.value.slen = 0
        else:
            _str_to_pj_str(value, &param.value)
        pj_list_insert_after(<pj_list *> param_list, <pj_list *> param)
    return 0

cdef int _rdata_info_to_dict(pjsip_rx_data *rdata, dict info_dict) except -1:
    cdef pjsip_msg_body *body
    cdef pjsip_hdr *hdr
    cdef object hdr_name
    cdef int i
    cdef pjsip_generic_array_hdr *array_hdr
    cdef pjsip_generic_string_hdr *string_hdr
    cdef pjsip_contact_hdr *contact_hdr
    cdef pjsip_clen_hdr *clen_hdr
    cdef pjsip_ctype_hdr *ctype_hdr
    cdef pjsip_cseq_hdr *cseq_hdr
    cdef pjsip_generic_int_hdr *int_hdr
    cdef pjsip_fromto_hdr *fromto_hdr
    cdef pjsip_routing_hdr *routing_hdr
    cdef pjsip_retry_after_hdr *retry_after_hdr
    cdef pjsip_via_hdr *via_hdr
    cdef object hdr_data, hdr_multi
    cdef object headers = {}
    info_dict["headers"] = headers
    hdr = <pjsip_hdr *> (<pj_list *> &rdata.msg_info.msg.hdr).next
    while hdr != &rdata.msg_info.msg.hdr:
        hdr_data = None
        hdr_multi = False
        hdr_name = _pj_str_to_str(hdr.name)
        if hdr_name in ["Accept", "Allow", "Require", "Supported", "Unsupported"]:
            array_hdr = <pjsip_generic_array_hdr *> hdr
            hdr_data = []
            for i from 0 <= i < array_hdr.count:
                hdr_data.append(_pj_str_to_str(array_hdr.values[i]))
        elif hdr_name == "Contact":
            hdr_multi = True
            hdr_data = FrozenContactHeader_create(<pjsip_contact_hdr *> hdr)
        elif hdr_name == "Content-Length":
            clen_hdr = <pjsip_clen_hdr *> hdr
            hdr_data = clen_hdr.len
        elif hdr_name == "Content-Type":
            ctype_hdr = <pjsip_ctype_hdr *> hdr
            hdr_data = ("%s/%s" % (_pj_str_to_str(ctype_hdr.media.type),
                                   _pj_str_to_str(ctype_hdr.media.subtype)),
                                   _pj_str_to_str(ctype_hdr.media.param))
        elif hdr_name == "CSeq":
            cseq_hdr = <pjsip_cseq_hdr *> hdr
            hdr_data = (cseq_hdr.cseq, _pj_str_to_str(cseq_hdr.method.name))
        elif hdr_name in ["Expires", "Max-Forwards", "Min-Expires"]:
            int_hdr = <pjsip_generic_int_hdr *> hdr
            hdr_data = int_hdr.ivalue
        elif hdr_name == "From":
            hdr_data = FrozenFromHeader_create(<pjsip_fromto_hdr *> hdr)
        elif hdr_name == "To":
            hdr_data = FrozenToHeader_create(<pjsip_fromto_hdr *> hdr)
        elif hdr_name == "Route":
            hdr_multi = True
            hdr_data = FrozenRouteHeader_create(<pjsip_routing_hdr *> hdr)
        elif hdr_name == "Record-Route":
            hdr_multi = True
            hdr_data = FrozenRecordRouteHeader_create(<pjsip_routing_hdr *> hdr)
        elif hdr_name == "Retry-After":
            hdr_data = FrozenRetryAfterHeader_create(<pjsip_retry_after_hdr *> hdr)
        elif hdr_name == "Via":
            hdr_multi = True
            hdr_data = FrozenViaHeader_create(<pjsip_via_hdr *> hdr)
        elif hdr_name == "Warning":
            match = _re_warning_hdr.match(_pj_str_to_str((<pjsip_generic_string_hdr *>hdr).hvalue))
            if match is not None:
                hdr_data = FrozenWarningHeader(**match.groupdict())
        # skip the following headers:
        elif hdr_name not in ["Authorization", "Proxy-Authenticate", "Proxy-Authorization", "WWW-Authenticate"]:
            string_hdr = <pjsip_generic_string_hdr *> hdr
            hdr_data = FrozenHeader(hdr_name, _pj_str_to_str(string_hdr.hvalue))
        if hdr_data is not None:
            if hdr_multi:
                headers.setdefault(hdr_name, []).append(hdr_data)
            else:
                if hdr_name not in headers:
                    headers[hdr_name] = hdr_data
        hdr = <pjsip_hdr *> (<pj_list *> hdr).next
    body = rdata.msg_info.msg.body
    if body == NULL:
        info_dict["body"] = None
    else:
        info_dict["body"] = PyString_FromStringAndSize(<char *> body.data, body.len)
    if rdata.msg_info.msg.type == PJSIP_REQUEST_MSG:
        info_dict["method"] = _pj_str_to_str(rdata.msg_info.msg.line.req.method.name)
        info_dict["request_uri"] = FrozenSIPURI_create(<pjsip_sip_uri*>rdata.msg_info.msg.line.req.uri)
    else:
        info_dict["code"] = rdata.msg_info.msg.line.status.code
        info_dict["reason"] = _pj_str_to_str(rdata.msg_info.msg.line.status.reason)
    return 0

cdef int _is_valid_ip(int af, object ip) except -1:
    cdef char buf[16]
    cdef pj_str_t src
    cdef int status
    _str_to_pj_str(ip, &src)
    status = pj_inet_pton(af, &src, buf)
    if status == 0:
        return 1
    else:
        return 0

cdef int _get_ip_version(object ip) except -1:
    if _is_valid_ip(pj_AF_INET(), ip):
        return pj_AF_INET()
    elif _is_valid_ip(pj_AF_INET6(), ip):
        return pj_AF_INET()
    else:
        return 0

cdef int _add_headers_to_tdata(pjsip_tx_data *tdata, object headers) except -1:
    cdef object name, value
    cdef pj_str_t name_pj, value_pj
    cdef pjsip_hdr *hdr
    for header in headers:
        _str_to_pj_str(header.name, &name_pj)
        _str_to_pj_str(header.body, &value_pj)
        hdr = <pjsip_hdr *> pjsip_generic_string_hdr_create(tdata.pool, &name_pj, &value_pj)
        pjsip_msg_add_hdr(tdata.msg, hdr)

# globals

cdef object _re_pj_status_str_def = re.compile("^.*\((.*)\)$")
cdef object _re_warning_hdr = re.compile('(?P<code>[0-9]{3}) (?P<agent>.*?) "(?P<text>.*?)"')
sip_status_messages = SIPStatusMessages()
