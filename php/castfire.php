<?php
/* Copyright (c) 2008 Castfire, Inc
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * ----------------------------------------------------------------------------
 * pear/Castfire/API.php
 * http://www.castfire.com/
 * Version 1.0 2007-12-21
 *
 * Castfire API example client.
 *
 * This class requires PHP 5 and the HTTP_Request pear class:
 * http://pear.php.net/manual/en/package.http.http-request.php
 *
 * Example:
 * $api_client = new Castfire_API(array('api_key'=>'11111-22222-33333', 'api_secret'=>'AbcdefgHijklmnoP'));
 *
 * $xml = $api_client->callMethod('shows.getInfo', array('show_id'=>99999));
 *
 * echo "show name: " .  $xml->show->name;
 */
require_once 'HTTP/Request.php';

class Castfire_API 
{

	var $_cfg = array(
			'api_key'	=> '',
			'api_secret'	=> '',
			'format' => 'xml',
			'endpoint'	=> 'http://api.castfire.com/rest/',
			'conn_timeout'	=> 5,
			'io_timeout'	=> 5,
		);

	var $_err_code = 0;
	var $_err_msg = '';
	var $xml;

	function Castfire_API($params = array())
	{
		foreach($params as $k => $v)
		{
			$this->_cfg[$k] = $v;
		}
	}

	function callMethod($method, $params = array())
	{
		$this->_err_code = 0;
		$this->_err_msg = '';

		$p = $params;
		$p['method'] = $method;
		$p['api_key'] = $this->_cfg['api_key'];

		if ($this->_cfg['api_secret'])
		{
			$p['api_sig'] = $this->signArgs($p);
		}

		$get = $this->makeGet($p);
		
		$url = $this->_cfg['endpoint'].$this->_cfg['format']."/?$get";

		$req =& new HTTP_Request($url, array('timeout' => $this->_cfg['conn_timeout']));

		$req->_readTimeout = array($this->_cfg['io_timeout'], 0);

		$req->sendRequest();

		$this->_http_code = $req->getResponseCode();
		$this->_http_head = $req->getResponseHeader();
		$this->_http_body = $req->getResponseBody();

		if ($this->_http_code != 200)
		{
			$this->_err_code = 0;

			if ($this->_http_code)
			{
				$this->_err_msg = "Bad response from remote server: HTTP status code $this->_http_code";
			}
			else
			{
				$this->_err_msg = "Couldn't connect to remote server";
			}

			return FALSE;
		}

		$this->xml = new SimpleXMLElement($this->_http_body);

		if (!isset($this->xml['status']))
		{
			$this->_err_code = 0;
			$this->_err_msg = "Bad XML response";
			
			return FALSE;
		}
		elseif ($this->xml['status'] == 'fail')
		{
			$this->_err_code = $this->xml->error['code'];
			$this->_err_msg = $this->xml->error['message'];

			return FALSE;
		}
		elseif($this->xml['status'] != 'ok')
		{
			$this->_err_code = 0;
			$this->_err_msg = "Unrecognised REST response status";
		}

		return $this->xml;
	}

	function getErrorCode()
	{
		return $this->_err_code;
	}

	function getErrorMessage()
	{
		return $this->_err_msg;
	}

	function signArgs($args)
	{
		ksort($args);
		$a = '';
		foreach($args as $k => $v)
		{
			$a .= $k . $v;
		}
		
		return md5($this->_cfg['api_secret'].$a);
	}
	
	function makeGet($args)
	{
		$p = array();
		foreach($args as $k => $v)
		{
			$p[] = urlencode($k).'='.urlencode($v);
		}

		return implode('&', $p);
	}
}
?>